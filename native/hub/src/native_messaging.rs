//! Named Pipe server for browser extension communication via Native Messaging.
//!
//! Architecture:
//!   - FluxDown main process creates a Named Pipe server at `\\.\pipe\fluxdown`.
//!   - The NMH relay binary (`fluxdown_nmh.exe`) connects to this pipe.
//!   - Messages use a 4-byte LE length prefix + JSON payload.
//!
//! Message protocol:
//!   - `{"action":"ping","msg_id":N}`     → `{"success":true,"message":"pong","msg_id":N}`
//!   - `{"action":"download","msg_id":N, ...}` → `{"success":true,"message":"download accepted","msg_id":N}`

use serde::{Deserialize, Serialize};
use tokio::sync::mpsc;

/// Named Pipe path for the NMH relay to connect to.
#[cfg(windows)]
const PIPE_NAME: &str = r"\\.\pipe\fluxdown";

/// Maximum message size: 1 MB.
const MAX_MESSAGE_SIZE: u32 = 1024 * 1024;

// ---------------------------------------------------------------------------
// Message types matching the browser extension protocol
// ---------------------------------------------------------------------------

/// Download request payload from the browser extension.
#[derive(Debug, Clone, Deserialize)]
pub struct DownloadRequest {
    pub url: String,
    #[serde(default)]
    pub filename: String,
    #[serde(default)]
    pub referrer: String,
    #[serde(default)]
    pub cookies: String,
    #[serde(default)]
    #[allow(dead_code)]
    pub headers: Option<std::collections::HashMap<String, String>>,
    #[serde(rename = "fileSize")]
    #[serde(default)]
    pub file_size: Option<u64>,
    #[serde(rename = "mimeType")]
    #[serde(default)]
    pub mime_type: Option<String>,
}

/// Incoming pipe message with action routing.
#[derive(Debug, Deserialize)]
struct PipeMessage {
    action: String,
    #[serde(default)]
    msg_id: u64,
    #[serde(flatten)]
    payload: serde_json::Value,
}

/// JSON response sent back via the pipe.
#[derive(Debug, Serialize)]
struct PipeResponse {
    success: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    message: Option<String>,
    msg_id: u64,
}

// ---------------------------------------------------------------------------
// Named Pipe server (Windows)
// ---------------------------------------------------------------------------

#[cfg(windows)]
mod server {
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    use tokio::net::windows::named_pipe::ServerOptions;
    use tokio::sync::mpsc;

    use super::{DownloadRequest, PipeMessage, PipeResponse, MAX_MESSAGE_SIZE, PIPE_NAME};

    /// Read a 4-byte LE length-prefixed message from the pipe.
    async fn read_framed_message(
        pipe: &mut tokio::net::windows::named_pipe::NamedPipeServer,
    ) -> Result<Vec<u8>, std::io::Error> {
        let mut len_buf = [0u8; 4];
        pipe.read_exact(&mut len_buf).await?;
        let len = u32::from_le_bytes(len_buf);
        if len == 0 || len > MAX_MESSAGE_SIZE {
            return Err(std::io::Error::new(
                std::io::ErrorKind::InvalidData,
                format!("invalid message length: {}", len),
            ));
        }
        let mut buf = vec![0u8; len as usize];
        pipe.read_exact(&mut buf).await?;
        Ok(buf)
    }

    /// Write a 4-byte LE length-prefixed message to the pipe.
    async fn write_framed_message(
        pipe: &mut tokio::net::windows::named_pipe::NamedPipeServer,
        data: &[u8],
    ) -> Result<(), std::io::Error> {
        let len = data.len() as u32;
        pipe.write_all(&len.to_le_bytes()).await?;
        pipe.write_all(data).await?;
        pipe.flush().await?;
        Ok(())
    }

    /// Handle a single pipe client connection.
    async fn handle_pipe_client(
        mut pipe: tokio::net::windows::named_pipe::NamedPipeServer,
        tx: mpsc::Sender<DownloadRequest>,
    ) {
        loop {
            let raw = match read_framed_message(&mut pipe).await {
                Ok(data) => data,
                Err(e) => {
                    rinf::debug_print!("[nmh-pipe] read error: {}", e);
                    break;
                }
            };

            let msg: PipeMessage = match serde_json::from_slice(&raw) {
                Ok(m) => m,
                Err(e) => {
                    rinf::debug_print!("[nmh-pipe] JSON parse error: {}", e);
                    let resp = PipeResponse {
                        success: false,
                        message: Some(format!("invalid JSON: {}", e)),
                        msg_id: 0,
                    };
                    if let Ok(json) = serde_json::to_vec(&resp)
                        && write_framed_message(&mut pipe, &json).await.is_err()
                    {
                        break;
                    }
                    continue;
                }
            };

            let response = match msg.action.as_str() {
                "ping" => {
                    rinf::debug_print!("[nmh-pipe] ping (msg_id={})", msg.msg_id);
                    PipeResponse {
                        success: true,
                        message: Some("pong".to_string()),
                        msg_id: msg.msg_id,
                    }
                }
                "download" => {
                    match serde_json::from_value::<DownloadRequest>(msg.payload) {
                        Ok(download_req) => {
                            rinf::debug_print!(
                                "[nmh-pipe] download request (msg_id={}): url={}",
                                msg.msg_id,
                                download_req.url
                            );
                            let _ = tx.send(download_req).await;
                            PipeResponse {
                                success: true,
                                message: Some("download accepted".to_string()),
                                msg_id: msg.msg_id,
                            }
                        }
                        Err(e) => {
                            rinf::debug_print!(
                                "[nmh-pipe] download parse error (msg_id={}): {}",
                                msg.msg_id,
                                e
                            );
                            PipeResponse {
                                success: false,
                                message: Some(format!("invalid download payload: {}", e)),
                                msg_id: msg.msg_id,
                            }
                        }
                    }
                }
                other => {
                    rinf::debug_print!(
                        "[nmh-pipe] unknown action '{}' (msg_id={})",
                        other,
                        msg.msg_id
                    );
                    PipeResponse {
                        success: false,
                        message: Some(format!("unknown action: {}", other)),
                        msg_id: msg.msg_id,
                    }
                }
            };

            if let Ok(json) = serde_json::to_vec(&response)
                && write_framed_message(&mut pipe, &json).await.is_err()
            {
                break;
            }
        }
    }

    /// Spawn the Named Pipe server.
    pub fn spawn_listener() -> mpsc::Receiver<DownloadRequest> {
        let (tx, rx) = mpsc::channel::<DownloadRequest>(64);

        tokio::spawn(async move {
            rinf::debug_print!("[nmh-pipe] starting Named Pipe server at {}", PIPE_NAME);

            // Create the first server instance before entering the loop.
            let mut server = match ServerOptions::new()
                .first_pipe_instance(true)
                .create(PIPE_NAME)
            {
                Ok(s) => s,
                Err(e) => {
                    rinf::debug_print!("[nmh-pipe] failed to create pipe server: {}", e);
                    return;
                }
            };

            loop {
                // Wait for a client to connect.
                if let Err(e) = server.connect().await {
                    rinf::debug_print!("[nmh-pipe] connect error: {}", e);
                    // Brief pause before retrying.
                    tokio::time::sleep(std::time::Duration::from_millis(100)).await;
                    continue;
                }

                rinf::debug_print!("[nmh-pipe] client connected");

                // Create the next server instance to accept the next client
                // while we handle the current one.
                let next_server = match ServerOptions::new().create(PIPE_NAME) {
                    Ok(s) => s,
                    Err(e) => {
                        rinf::debug_print!("[nmh-pipe] failed to create next pipe instance: {}", e);
                        // Can't accept more clients, but handle the current one.
                        let tx_clone = tx.clone();
                        tokio::spawn(handle_pipe_client(server, tx_clone));
                        // Exit the accept loop — single client mode until restart.
                        break;
                    }
                };

                // Hand off the connected server to a task.
                let connected = std::mem::replace(&mut server, next_server);
                let tx_clone = tx.clone();
                tokio::spawn(handle_pipe_client(connected, tx_clone));
            }
        });

        rx
    }
}

// Non-Windows stub — Named Pipes are Windows-only.
#[cfg(not(windows))]
mod server {
    use tokio::sync::mpsc;

    use super::DownloadRequest;

    pub fn spawn_listener() -> mpsc::Receiver<DownloadRequest> {
        let (_tx, rx) = mpsc::channel::<DownloadRequest>(1);
        rinf::debug_print!("[nmh-pipe] Named Pipe server is Windows-only, skipping");
        rx
    }
}

/// Spawn the Named Pipe server that listens for incoming browser extension
/// requests relayed through the NMH binary.
///
/// Returns a receiver that yields `DownloadRequest` items whenever the
/// browser extension sends a download request via Native Messaging.
/// Ping requests are handled internally (immediate pong response).
pub fn spawn_native_messaging_listener() -> mpsc::Receiver<DownloadRequest> {
    server::spawn_listener()
}
