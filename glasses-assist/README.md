# Glasses Assist (Pi Zero 2 W + Flutter iOS/Android)

Kính trợ lực cho người mù: Pi Zero 2 W + Camera Module 3 (Wide) gắn trên kính, phát RTSP qua Wi-Fi AP riêng.
App Flutter (iOS/Android) nhận video, phát hiện chướng ngại (TFLite), OCR (ML Kit), TTS tiếng Việt và rung cảnh báo.
Có **Power Save Mode** để **tiết kiệm pin** trên cả Pi và điện thoại.

## Kiến trúc
- **Pi**: AP `PiVision` (WPA2), RTSP `rtsp://192.168.50.1:8554/unicast` (720p@25fps, H.264 ~3.5–4 Mbps).
- **App**: Flutter chung iOS/Android. RTSP (libVLC), Detector (TFLite), OCR (ML Kit), TTS (flutter_tts), rung (vibration).
  - Power Save: giảm tần số xử lý, giảm input model, tăng throttle TTS.

## Cách chạy nhanh
1) **Pi**
   - Cài `hostapd`, `dnsmasq`, `v4l2rtspserver`.
   - Copy `pi/*.conf` & `pi/*.service` vào đúng vị trí hệ thống (xem file trong `pi/`).
   - Bật dịch vụ: `sudo systemctl enable --now hostapd dnsmasq rtsp.service`
   - (Tuỳ chọn) tiết kiệm pin: `sudo systemctl enable --now powersave.service`
2) **Model**
   - Tải **SSD MobileNet V2 COCO (300×300) TFLite** → đặt vào `mobile/assets/models/detector.tflite`
   - (Hoặc YOLOv8n TFLite; khi đó thay `detector_ssd.dart` bằng decoder YOLO).
3) **App**
   - `cd mobile && flutter pub get`
   - **iOS**: `cd ios && pod install` → mở `Runner.xcworkspace` → chạy iPhone (iOS 15+)
   - **Android**: mở `mobile/` bằng Android Studio → build (Android 10+)
4) **Dùng**
   - Điện thoại kết nối Wi-Fi **PiVision** → mở app (mặc định chế độ dò chướng ngại).
   - Nút **Đọc chữ** để OCR.
   - Nút **Power Save** để **tiết kiệm pin** (giảm FPS xử lý, model input nhẹ hơn).

## Lưu ý tiết kiệm pin (rất quan trọng)
- **Trên Pi**
  - Dùng `pi/powersave.service` để hạ công suất Wi-Fi và CPU governor về `powersave`.
  - Nếu cần tăng pin: hạ RTSP xuống **20 fps** và/hoặc 960×540.
- **Trên App**
  - Bật **Power Save** để: xử lý khung **~5 Hz**, giảm input model, TTS thưa hơn.
  - Khi không cần dò, tắt “Dò chướng ngại” (chỉ bật khi đi ngoài đường).

