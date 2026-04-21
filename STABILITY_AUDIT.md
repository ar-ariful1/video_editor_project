# 🛡️ ClipCut Engine - Final Stability Audit Checklist

| Category | Task | Status |
| :--- | :--- | :--- |
| **Memory** | Check for GPU Texture leaks in `TextureCache` | [ ] |
| **Memory** | Verify JNI local reference table limits (max 512) | [ ] |
| **Threading** | Stress test `ThreadPool` with 100+ concurrent tasks | [ ] |
| **A/V Sync** | Validate 1-hour export for drift (> 100ms) | [ ] |
| **Quality** | Check HEVC bitrate consistency on low-end SoC | [ ] |
| **Stability** | Test Crash-Recovery by killing process during export | [ ] |
| **Performance**| Measure Frame Drop rate on 2GB RAM devices | [ ] |
