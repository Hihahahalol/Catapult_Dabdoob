import subprocess
from pathlib import Path

# Custom audio file selections using AtsSoundpack backup + @'s soundpack
CUSTOM_FILES = [
    # 1. 9mm shoot - from AtsSoundpack backup
    "H:/bitburner repo/Soundpack backup/AtsSoundpack/shoot_9mm.ogg",
    
    # 2. male hurt - from AtsSoundpack backup
    "H:/bitburner repo/Soundpack backup/AtsSoundpack/hurt_male.ogg",
    
    # 3. window shatter - from AtsSoundpack backup
    "H:/bitburner repo/Soundpack backup/AtsSoundpack/break_window.ogg",
    
    # 4. footstep - from AtsSoundpack backup
    "H:/bitburner repo/Soundpack backup/AtsSoundpack/walk.ogg",
    
    # 5. baton hit - from AtsSoundpack backup
    "H:/bitburner repo/Soundpack backup/AtsSoundpack/hit_baton.ogg",
    
    # 6. female hurt - from AtsSoundpack backup
    "H:/bitburner repo/Soundpack backup/AtsSoundpack/hurt_female.ogg",
    
    # 7. car engine start - from @'s soundpack
    "H:/Godot Exports/tlg/userdata/sound/@'s soundpack/vehicle/engine/engine_start_combustion_1.wav",
    
    # 8. drive - from @'s soundpack
    "H:/Godot Exports/tlg/userdata/sound/@'s soundpack/vehicle/engine/engine_stall_1.wav",
    
    # 9. explosion - from @'s soundpack
    "H:/Godot Exports/tlg/userdata/sound/@'s soundpack/env/explosions/explosion_large_3.ogg",
]

OUTPUT_DIR = Path("H:/bitburner repo/Catapult_TLG/materials/sound_samples")
OUTPUT_FILE = OUTPUT_DIR / "@'s soundpack_combined.ogg"
SILENCE_FILE = OUTPUT_DIR / "silence_0.25s.wav"

def create_custom_combined():
    """Create combined audio with custom file selections."""
    
    print("Creating custom @'s soundpack combined file...")
    print(f"Using {len(CUSTOM_FILES)} sound files with 0.25s silence between each\n")
    
    # Verify all files exist
    missing_files = []
    for i, file_path in enumerate(CUSTOM_FILES, 1):
        path = Path(file_path)
        if not path.exists():
            missing_files.append(f"  {i}. {file_path}")
            print(f"  ! File {i} NOT FOUND: {path.name}")
        else:
            print(f"  + File {i}: {path.name}")
    
    if missing_files:
        print(f"\nERROR: {len(missing_files)} file(s) not found!")
        return False
    
    # Ensure silence file exists
    if not SILENCE_FILE.exists():
        print("\nCreating silence file...")
        silence_cmd = [
            "ffmpeg", "-y", "-f", "lavfi",
            "-i", "anullsrc=r=44100:cl=mono,atrim=0:0.25",
            "-q:a", "9",
            str(SILENCE_FILE)
        ]
        try:
            subprocess.run(silence_cmd, check=True, capture_output=True)
            print("  + Silence file created")
        except subprocess.CalledProcessError as e:
            print(f"  - Error creating silence file: {e}")
            return False
    
    # Build ffmpeg command
    cmd = ["ffmpeg", "-y"]
    input_count = 0
    filter_parts = []
    
    # Add audio files as inputs
    for file_path in CUSTOM_FILES:
        cmd.extend(["-i", file_path])
        filter_parts.append(f"[{input_count}]")
        input_count += 1
        
        # Add silence after each file (except the last)
        if file_path != CUSTOM_FILES[-1]:
            cmd.extend(["-i", str(SILENCE_FILE)])
            filter_parts.append(f"[{input_count}]")
            input_count += 1
    
    # Build concat filter
    filter_str = "".join(filter_parts) + f"concat=n={input_count}:v=0:a=1[out]"
    
    cmd.extend([
        "-filter_complex", filter_str,
        "-map", "[out]",
        "-q:a", "9",
        str(OUTPUT_FILE)
    ])
    
    # Run ffmpeg
    print("\nRunning ffmpeg to combine audio files...")
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            print(f"  - Error: {result.stderr}")
            return False
        
        print(f"  + Successfully created {OUTPUT_FILE.name}")
        return True
        
    except Exception as e:
        print(f"  - Exception: {e}")
        return False

if __name__ == "__main__":
    success = create_custom_combined()
    
    if success:
        # Verify the output
        print("\nVerifying output file...")
        try:
            result = subprocess.run(
                ["ffprobe", "-v", "error", "-show_format", str(OUTPUT_FILE)],
                capture_output=True,
                text=True
            )
            if "duration" in result.stdout:
                for line in result.stdout.split("\n"):
                    if "duration" in line:
                        print(f"  + {line}")
        except:
            pass
        
        print("\n" + "=" * 60)
        print("SUCCESS: Custom @'s soundpack combined file created!")
        print("=" * 60)
    else:
        print("\n" + "=" * 60)
        print("FAILED: Could not create custom combined file")
        print("=" * 60)
