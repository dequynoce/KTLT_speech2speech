# Quick Start

Repo này đã gộp sẵn `MeloTTS/` và `OpenVoice/`, nên chỉ cần làm một lần ở thư mục gốc:

```powershell
.\setup.ps1
```

Script sẽ:

1. Tạo `.venv` nếu chưa có.
2. Cài toàn bộ dependency từ `requirements.txt`.
3. Chạy `python -m unidic download`.
4. Tải checkpoint OpenVoice về local và giải nén vào `checkpoints_v2/`.

Sau đó mở `speech_2_speech.ipynb` và chạy notebook từ trên xuống dưới.

Nếu PowerShell chặn script, chạy:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

Sau đó chạy lại `.
setup.ps1`.