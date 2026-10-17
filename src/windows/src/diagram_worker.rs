//! One on-demand renderer, sharing WebView2's browser/GPU with the reader but
//! using an isolated origin and renderer process. No diagram engine in the UI.
use crate::{win32, UserEvent};
use serde_json::{json, Value};
use std::{
    borrow::Cow,
    collections::HashSet,
    time::{Duration, Instant},
};
use tao::{event_loop::EventLoopProxy, window::Window};
use wry::{WebContext, WebView, WebViewBuilder};

#[derive(Default)]
pub struct DiagramWorker {
    view: Option<WebView>,
    active: Option<Value>,
    ready: bool,
    loaded: HashSet<String>,
    session: String,
    deadline: Option<Instant>,
}
impl DiagramWorker {
    pub fn has_renderer(&self) -> bool {
        self.view.is_some()
    }
    pub fn submit(
        &mut self,
        text: &str,
        window: &Window,
        context: &mut WebContext,
        proxy: &EventLoopProxy<UserEvent>,
    ) -> Option<Value> {
        let job: Value = serde_json::from_str(text).ok()?;
        let id = job["id"].as_str()?.to_owned();
        let valid = matches!(job["renderer"].as_str(), Some("mermaid" | "plantuml"))
            && job["source"].as_str().is_some_and(|s| s.len() <= 1_000_000)
            && !id.is_empty();
        if !valid || self.active.is_some() {
            return Some(json!({"id":id,"error":"Invalid or excessive diagram request"}));
        }
        self.active = Some(job);
        self.deadline = Some(Instant::now() + Duration::from_secs(30));
        if self.view.is_none() {
            if let Err(error) = self.create(window, context, proxy) {
                return self.fail(error.to_string());
            }
        }
        if self.ready {
            self.start(proxy)
        } else {
            None
        }
    }
    fn create(
        &mut self,
        window: &Window,
        context: &mut WebContext,
        proxy: &EventLoopProxy<UserEvent>,
    ) -> Result<(), Box<dyn std::error::Error>> {
        self.session = format!(
            "{:x}",
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)?
                .as_nanos()
        );
        let nonce = &self.session;
        let script = include_str!("../../../assets/diagram-renderer.js");
        let html = format!(
            r#"<!doctype html><html><head><meta charset="utf-8"><meta name="mdvu-script-nonce" content="{nonce}"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'nonce-{nonce}' 'unsafe-eval' 'wasm-unsafe-eval'; style-src 'unsafe-inline'; img-src data: blob:; font-src data:; worker-src blob:; connect-src 'none'; object-src 'none'; form-action 'none'"><style>body{{margin:0;font:16px Arial,sans-serif}}</style></head><body><script nonce="{nonce}">window.__mdvuRendererSession='{nonce}';{script}</script></body></html>"#
        );
        let view = WebViewBuilder::with_web_context(context)
            .with_custom_protocol("mdvu-diagram".into(), move |_, _| {
                wry::http::Response::builder()
                    .header("Content-Type", "text/html; charset=utf-8")
                    .body(Cow::Owned(html.as_bytes().to_vec()))
                    .expect("Static renderer response")
            })
            .with_url("mdvu-diagram://localhost/")
            .with_bounds(wry::Rect {
                position: tao::dpi::LogicalPosition::new(0., 0.).into(),
                size: tao::dpi::LogicalSize::new(920., 800.).into(),
            })
            .with_visible(false)
            .build(window)?;
        let proxy = proxy.clone();
        win32::attach_web_message_handler(
            &view,
            "http://mdvu-diagram.localhost/",
            move |message| {
                let _ = proxy.send_event(UserEvent::DiagramMessage(message.to_owned()));
            },
        )?;
        self.view = Some(view);
        Ok(())
    }
    fn start(&mut self, proxy: &EventLoopProxy<UserEvent>) -> Option<Value> {
        let job = self.active.as_ref()?;
        let renderer = job["renderer"].as_str()?;
        if self.loaded.contains(renderer) {
            return self.execute("");
        }
        let id = job["id"].as_str()?.to_owned();
        let getter = if renderer == "mermaid" {
            mdvu_core::get_mermaid_js
        } else {
            mdvu_core::get_plantuml_js
        };
        let proxy = proxy.clone();
        std::thread::spawn(move || {
            let _ = proxy.send_event(UserEvent::DiagramRuntimeReady(id, getter()));
        });
        None
    }
    pub fn runtime_ready(
        &mut self,
        id: &str,
        source: Result<&'static str, &'static str>,
    ) -> Option<Value> {
        let job = self.active.as_ref()?;
        if job["id"].as_str() != Some(id) {
            return None;
        }
        match source {
            Ok(source) => {
                self.loaded.insert(job["renderer"].as_str()?.to_owned());
                self.execute(source)
            }
            Err(error) => self.fail(error.into()),
        }
    }
    fn execute(&mut self, source: &str) -> Option<Value> {
        let script = format!(
            "{source};window.__mdvuRunDiagramJob({});void 0",
            self.active.as_ref()?
        );
        if let Err(error) = self.view.as_ref()?.evaluate_script(&script) {
            return self.fail(error.to_string());
        }
        None
    }
    pub fn message(&mut self, text: &str, proxy: &EventLoopProxy<UserEvent>) -> Option<Value> {
        let result = self.verified_message(text)?;
        if result["ready"] == true {
            self.ready = true;
            return self.start(proxy);
        }
        if result["id"] != self.active.as_ref()?["id"] {
            return None;
        }
        self.active = None;
        self.deadline = Some(Instant::now() + Duration::from_secs(5));
        Some(result)
    }
    fn verified_message(&self, text: &str) -> Option<Value> {
        let result: Value = serde_json::from_str(text).ok()?;
        (!self.session.is_empty() && result["session"].as_str() == Some(self.session.as_str()))
            .then_some(result)
    }
    fn fail(&mut self, error: String) -> Option<Value> {
        let job = self.active.take()?;
        self.release();
        Some(json!({"id":job["id"],"error":error}))
    }
    fn release(&mut self) {
        self.view = None;
        self.ready = false;
        self.loaded.clear();
        self.deadline = None;
        self.session.clear();
    }
    pub fn cancel(&mut self) {
        self.active = None;
        self.release();
    }
    pub fn poll(&mut self) -> Option<Value> {
        if self.deadline.is_some_and(|t| Instant::now() >= t) {
            if self.active.is_some() {
                return self.fail("Diagram rendering timed out".into());
            }
            self.release();
        }
        None
    }
    pub fn deadline(&self) -> Option<Instant> {
        self.deadline
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cancelled_renderer_cannot_mark_a_new_renderer_ready() {
        let mut worker = DiagramWorker {
            session: "old".into(),
            active: Some(json!({"id":"obsolete"})),
            ..Default::default()
        };
        worker.cancel();
        assert!(worker
            .verified_message(r#"{"session":"old","ready":true}"#)
            .is_none());
        worker.session = "new".into();
        assert!(worker
            .verified_message(r#"{"session":"old","id":"obsolete","svg":"stale"}"#)
            .is_none());
        assert!(worker
            .verified_message(r#"{"session":"new","ready":true}"#)
            .is_some());
    }

    #[test]
    fn timed_out_work_fails_once_and_releases_the_renderer() {
        let mut worker = DiagramWorker {
            active: Some(json!({"id":"slow"})),
            session: "expired".into(),
            deadline: Some(Instant::now() - Duration::from_secs(1)),
            ..Default::default()
        };
        let result = worker.poll().unwrap();
        assert_eq!(result["id"], "slow");
        assert_eq!(result["error"], "Diagram rendering timed out");
        assert!(worker.poll().is_none());
        assert!(worker
            .verified_message(r#"{"session":"expired","ready":true}"#)
            .is_none());
    }
}
