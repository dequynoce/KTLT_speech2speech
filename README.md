# BÁO CÁO DỰ ÁN: HỆ THỐNG CHUYỂN ĐỔI GIỌNG NÓI TRÊN VIDEO (SPEECH-TO-SPEECH VOICE CONVERSION SYSTEM)

* **Khóa học:** Xử lý ngôn ngữ tự nhiên / Học sâu / Khai phá dữ liệu
* **Cơ sở đào tạo:** Trường Công nghệ Thông tin và Truyền thông - Đại học Bách Khoa Hà Nội (HUST)
* **Sinh viên thực hiện:** Dương Quốc Chính
* **Môi trường thực thi:** Môi trường ảo hóa cục bộ (`.venv` - Python 3.10) cô lập hoàn toàn với Hệ điều hành.

---

## 1. TỔNG QUAN ĐỀ TÀI & MỤC TIÊU
Yêu cầu cốt lõi của bài tập là xây dựng một hệ thống tự động xử lý đa phương tiện nâng cao. Đầu vào là một video bài giảng/hội thoại trên YouTube có giọng đọc gốc tiếng Anh-Ấn (Indian accent). Hệ thống cần chuyển đổi toàn bộ phần hội thoại sang giọng đọc Anh-Mỹ chuẩn (American accent) nhưng phải đảm bảo:
1. **Giữ nguyên nhịp điệu (Tempo/Prosody):** Tốc độ nói, khoảng ngắt nghỉ của người nói trong video gốc không thay đổi.
2. **Khớp khẩu hình (Lip-sync preservation):** Phần luồng hình ảnh (Video stream) không bị biến đổi, thời gian âm thanh mới phải trùng khớp tuyệt đối với chuyển động môi của nhân vật.
3. **Độc lập và sạch sẽ hệ thống (System Isolation):** Mã nguồn ban đầu được thiết kế chạy trên đám mây Linux (Google Colab) sử dụng nhiều lệnh Shell hệ thống. Dự án này đã tái cấu trúc toàn bộ mã nguồn sang Python thuần để chạy mượt mà trong môi trường ảo sandbox trên Windows mà không tạo ra bất kỳ tàn dư "rác" nào trong biến môi trường hệ thống.

---

## 2. KIẾN TRÚC LUỒNG XỬ LÝ (PIPELINE ARCHITECTURE)

Dự án được xây dựng dựa trên một luồng xử lý khép kín gồm 6 giai đoạn chính:

```
[YouTube URL] ──> (1. Tách Luồng) ──┬──> [video_no_audio.mp4] (Câm) ──────────────────────────────────────┐
                                    └──> [Variable Characteristics.mp3] (Giọng Ấn)                         │
                                                        │                                                  │
                                                        ▼                                                  ▼
                                            (2. Thuật toán Cắt mẩu)                                (6. Muxing bằng FFmpeg)
                                                        │                                                  │
                                                        ▼                                                  │
                                            [Mẩu 30s] ... [Mẩu gộp cuối]                                   │
                                                        │                                                  │
                                                        ▼                                                  │
[sample_American_accent.mp3] ─────────────> (3. Trích xuất Tone Color)                                    │
                                                        │                                                  │
                                                        ▼                                                  ▼
                                            (4. Khử nhiễu & Đổi giọng) ──> [Nối Audio] ──> [Audio Mỹ.wav] ──> [Final_Video.mp4]
```

### Giai đoạn 1: Trích xuất và Tách ly luồng đa phương tiện (Data Muxing Separation)
Sử dụng thư viện mã nguồn mở `yt-dlp` để phân tách trực tiếp luồng phát của YouTube (ID: `2Q0TpVYet3A`).
* **Luồng hình (Video-only):** Tải luồng video không kèm âm thanh với codec chuẩn `avc1` (H.264), lưu thành tệp tin `video_no_audio.mp4`.
* **Luồng tiếng (Audio-only):** Tải luồng âm thanh gốc (định dạng mặc định `.webm`), sau đó kích hoạt bộ hậu xử lý cục bộ chuyển đổi sang định dạng `.mp3` chất lượng cao (192kbps), lấy tên `Variable Characteristics.mp3`.

### Giai đoạn 2: Thuật toán Phân đoạn Thích ứng chống lỗi Phân mảnh (Adaptive Chunking Algorithm)
Do tài nguyên VRAM/RAM giới hạn khi chạy mô hình học sâu (Deep Learning) trên máy cục bộ, âm thanh gốc dài hơn 6 phút bắt buộc phải chia nhỏ thành các đoạn (chunks) ngắn để xử lý song song hoặc tuần tự.
* **Vấn đề của thuật toán cũ:** Nếu chia cố định mỗi đoạn 30 giây (30000ms), đoạn cuối cùng sẽ bị rơi vào trạng thái "vỡ vụn" (chỉ dài 3.442 giây). Khi đưa đoạn quá ngắn này vào lõi AI OpenVoice, hàm phân tích cấu trúc giọng nói sẽ ném ra lỗi toán học nghiêm trọng: `AssertionError: input audio is too short` và làm sập toàn bộ hệ thống.
* **Giải pháp Tối ưu hóa Thuật toán:** Xây dựng cơ chế cấu hình động biên độ tối thiểu (`min_chunk_ms = 10000`). Nếu mẩu cuối cùng có độ dài nhỏ hơn 10 giây, thuật toán sẽ tự động thu hồi phần tử cuối (`chunks.pop()`) và tiến hành **gộp trực tiếp (merge)** nó vào đoạn áp chót liền trước. Kết quả là đoạn cuối cùng sẽ dài 33.4 giây, đảm bảo lõi mô hình AI có đủ lượng mẫu để học đặc trưng mà không làm tràn bộ nhớ VRAM.

### Giai đoạn 3: Trích xuất Đặc trưng Màu giọng (Tone Color Extraction)
Hệ thống sử dụng tệp mẫu `sample_American_accent.mp3` (độ dài 10-15 giây) chứa giọng Anh-Mỹ đích mong muốn. 
* Sử dụng mô hình `silero-vad` (Voice Activity Detection) để tự động quét toàn bộ dòng thời gian, loại bỏ hoàn toàn các khoảng lặng nhiễu môi trường, chỉ giữ lại tín hiệu sóng chứa giọng nói thuần túy.
* Mô hình trích xuất đặc trưng lớp tuyến tính của OpenVoice v2 tiến hành bóc tách ma trận vectơ màu giọng (Target Tone Color Vector `target_se`).

### Giai đoạn 4: Đổi màu giọng Zero-Shot (Voice Conversion Process)
Hệ thống duyệt qua danh sách các đoạn âm thanh đã cắt thích ứng:
1. Gọi hàm `se_extractor.get_se` để tính toán ma trận đặc trưng màu giọng của đoạn gốc (giọng Ấn độ - `source_se`).
2. Kích hoạt bộ chuyển đổi màu giọng `ToneColorConverter`. Hàm này thực hiện kỹ thuật toán học ánh xạ ma trận: Giữ nguyên hàm sóng cơ bản đại diện cho nhịp điệu, cao độ và từ ngữ của người nói gốc, nhưng thay thế hoàn toàn cấu trúc dải tần số cao (Formant/Timbre) bằng ma trận màu giọng Mỹ (`target_se`).
3. Xuất ra các mẩu âm thanh wav đã đổi giọng thành công mà không cần qua bước huấn luyện lại mô hình (Zero-Shot).

### Giai đoạn 5: Tái cấu trúc và Hợp nhất luồng âm thanh (Audio Reconstitution)
Sử dụng thư viện xử lý sóng âm `pydub`, hệ thống tạo một thực thể chuỗi sóng rỗng `AudioSegment.empty()`, sau đó duyệt tuần tự và cộng dồn các mẩu âm thanh Mỹ đã xử lý vào để tạo thành một tệp tổng hợp duy nhất: `American_accent_Variable_Characteristics.wav`, đảm bảo khớp 100% thời lượng của clip gốc.

### Giai đoạn 6: Trộn luồng đồng bộ (Subprocess Multimedia Muxing)
Gọi lệnh hệ thống thông qua `subprocess` của Python để thực thi phần mềm xử lý đa phương tiện FFmpeg:
* Ghép tệp hình ảnh không tiếng `video_no_audio.mp4` với tệp âm thanh giọng Mỹ mới tạo.
* Tham số truyền vào sử dụng cơ chế ép luồng tối ưu: `-c:v copy` (giữ nguyên gốc các pixel hình ảnh, không tốn tài nguyên encode lại hình để tránh giảm chất lượng hình ảnh) và `-c:a aac` (mã hóa âm thanh sang chuẩn AAC nén chất lượng cao).
* Kết quả xuất ra tệp thành phẩm cuối cùng: `Final_Variable_Characteristics_American.mp4`.

---

## 3. KIẾN TRÚC MÔI TRƯỜNG VÀ GIẢI PHÁP SẠCH CỤC BỘ (SANDBOXING SOLUTIONS)

Để đảm bảo hệ thống không tạo ra bất kỳ "rác" hay xung đột nào đối với máy tính Windows của người dùng, dự án đã áp dụng các giải pháp kỹ thuật môi trường sau:

1. **Chuyển đổi Đa nền tảng (Cross-platform Refactoring):** Toàn bộ các câu lệnh Linux CLI cũ như `!sed`, `!wget`, `!unzip` được thay bằng các thư viện chuẩn đa nền tảng của Python (`urllib.request`, `zipfile`, `shutil`). Điều này giúp file bài tập có tính linh hoạt tuyệt đối: nộp lại cho thầy chạy trên Google Colab (Linux) hay chạy máy cá nhân (Windows) đều chạy được ngay.
2. **Giải pháp Không can thiệp Hệ thống (Zero-System-Pollution):** * Thông thường, các thư viện AI xử lý âm thanh bắt buộc người dùng phải cài phần mềm FFmpeg vào hệ điều hành Windows và cấu hình bằng tay trong `Environment Variables` (Path). Điều này gây rác máy.
   * Bài tập này đã xử lý bằng cách tích hợp thư viện `static-ffmpeg`. Thư viện này tự động tải các file nhị phân `ffmpeg.exe` và `ffprobe.exe` cô lập bên trong thư mục môi trường ảo `.venv`.
   * Tại thời điểm runtime (khi ấn nút chạy cell code), Python sẽ kích hoạt lệnh `static_ffmpeg.add_paths()`, tự động chèn tạm thời đường dẫn của các file `.exe` này vào biến môi trường cục bộ `os.environ["PATH"]`. Khi tắt chương trình, các biến này tự động giải phóng, giữ hệ thống sạch sẽ hoàn toàn.

---

## 4. CẤU TRÚC THƯ MỤC DỰ ÁN (PROJECT DIRECTORY STRUCTURE)

Sau khi hệ thống chạy hoàn tất, cấu trúc cây thư mục trong workspace sẽ như sau:

```
Py/
├── .venv/                                      # Môi trường ảo Python cô lập hoàn toàn
├── checkpoints_v2/                             # Thư mục chứa trọng số checkpoint mô hình AI
│   └── converter/
│       ├── config.json
│       └── checkpoint.pth
├── MeloTTS/                                    # Mã nguồn thư viện phụ trợ MeloTTS từ GitHub
├── OpenVoice/                                  # Mã nguồn thư viện chuyển đổi giọng nói OpenVoice
├── temp_chunks/                                # Thư mục tạm lưu các mẩu âm thanh trong quá trình cắt
│   ├── chunk_0.wav ... chunk_12.wav            # Các mẩu âm thanh gốc đã gộp mẩu cuối
│   └── processed_chunk_0.wav ...               # Các mẩu âm thanh sau khi áp giọng Mỹ
├── processed/                                  # Bộ nhớ đệm lưu ma trận màu giọng của VAD
├── speech_2_speech.ipynb                       # File Notebook chính chứa toàn bộ mã nguồn bài tập
├── Variable Characteristics.mp3                # Âm thanh gốc (Giọng tiếng Anh-Ấn) tách từ YouTube
├── video_no_audio.mp4                          # Luồng hình ảnh gốc (Không âm thanh) tách từ YouTube
├── sample_American_accent.mp3                  # File âm thanh mẫu giọng Mỹ chuẩn tải về từ Drive
├── American_accent_Variable_Characteristics.wav# Thành phẩm âm thanh giọng Mỹ hoàn chỉnh (Hợp nhất)
└── Final_Variable_Characteristics_American.mp4 # THÀNH PHẨM VIDEO CUỐI CÙNG (Khớp khẩu hình, giọng Mỹ)
```

---

## 5. ĐÁNH GIÁ KẾT QUẢ & KẾT LUẬN

### Kết quả đạt được:
* Hệ thống hoàn thành trọn vẹn chuỗi xử lý tự động từ khâu nhập Link YouTube đến khâu kết xuất Video hoàn chỉnh.
* **Thời lượng và Khẩu hình:** Video thành phẩm `Final_Variable_Characteristics_American.mp4` giữ nguyên độ phân giải, tốc độ khớp hoàn toàn với chuyển động môi của nhân vật trong clip gốc. Người nghe không nhận ra sự lệch pha (desync) giữa hình và tiếng.
* **Chất lượng giọng nói:** Giọng đọc Ấn Độ ban đầu đã được chuyển hẳn sang âm điệu Mỹ, chuẩn hóa phát âm theo file mẫu.

### Hạn chế và Hướng phát triển:
* **Hiện tượng rè/nhiễu (Artifacts):** Do kiến trúc bộ Vocoder mã hóa giọng nói của OpenVoice v2 hoạt động theo cơ chế Zero-shot (học nhanh không cần huấn luyện lại), phần âm thanh đầu ra ở một số phân đoạn âm tần cao có hiện tượng hơi rè nhẹ (bị hiện tượng robotic hoặc reverbed). Điều này hoàn toàn là giới hạn công nghệ chung của mô hình toán học hiện tại khi không được tinh chỉnh sâu (fine-tune) với tập dữ liệu lớn của chính nhân vật.
* **Hướng phát triển:** Trong tương lai có thể cải tiến hệ thống bằng cách tích hợp thêm các bộ lọc nhiễu số (Digital Signal Processing - DSP) hoặc sử dụng bộ Vocoder nâng cao như BigVGAN để làm mượt dải âm tần đầu ra, giúp giọng nói tự nhiên, ấm và trong trẻo hơn.
