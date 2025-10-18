import os
import subprocess
import sys
from pathlib import Path

# Set UTF-8 encoding
sys.stdout.reconfigure(encoding='utf-8')

# Sound order as specified by user
SOUND_ORDER = [
    "9mm shoot",
    "male hurt",
    "window shatter",
    "footstep",
    "baton hit",
    "female hurt",
    "car engine start",
    "drive",
    "explosion"
]

# Sound mapping - map friendly names to folder/file patterns in each soundpack
SOUND_PATTERNS = {
    "9mm shoot": ["fire_gun/handguns", "fire_gun", "guns", "firearms"],
    "male hurt": ["deal_damage/hurt_m", "player/hurt_m", "hurt_m", "hurt"],
    "window shatter": ["smash_success/window", "smash/window", "smash_success", "smash"],
    "footstep": ["plmove", "player/move", "steps", "walk", "env/walk"],
    "baton hit": ["melee_hit_flesh/small_bash", "melee_hit_flesh", "melee"],
    "female hurt": ["deal_damage/hurt_f", "player/hurt_f", "hurt_f"],
    "car engine start": ["engine_start"],
    "drive": ["engine_working_external", "engine_working_internal", "vehicle"],
    "explosion": ["explosion", "explosions"]
}

# Soundpack directories
SOUND_DIR = Path("H:/Godot Exports/tlg/userdata/sound")
OUTPUT_DIR = Path("H:/bitburner repo/Catapult_TLG/materials/sound_samples")

def find_sound_file(soundpack_path, sound_name):
    """Find the first audio file matching the sound category."""
    soundpack = Path(soundpack_path)
    patterns = SOUND_PATTERNS.get(sound_name, [])
    
    for pattern in patterns:
        search_path = soundpack / pattern
        if search_path.exists() and search_path.is_dir():
            # Find first .ogg or .wav file
            for ext in ['.ogg', '.wav']:
                files = sorted(search_path.glob(f'*{ext}'))
                if files:
                    return str(files[0])
    
    # If not found in specified paths, search recursively for keyword matches
    keywords = sound_name.split()
    for keyword in keywords:
        if len(keyword) > 3:  # Only search for words longer than 3 chars
            # Search in directories matching the keyword
            for dir_path in soundpack.rglob('*'):
                if dir_path.is_dir() and keyword.lower() in dir_path.name.lower():
                    for ext in ['.ogg', '.wav']:
                        files = sorted(dir_path.glob(f'*{ext}'))
                        if files:
                            return str(files[0])
    
    return None

def create_combined_audio(soundpack_name, soundpack_path):
    """Create combined audio file for a soundpack with 2 seconds silence between each."""
    
    print(f"\nProcessing {soundpack_name}...")
    
    # Find audio files for each sound in order
    audio_files = []
    found_count = 0
    
    for sound_name in SOUND_ORDER:
        audio_file = find_sound_file(soundpack_path, sound_name)
        
        if audio_file:
            print(f"  + {sound_name}: {Path(audio_file).name}")
            audio_files.append(audio_file)
            found_count += 1
        else:
            print(f"  - {sound_name}: NOT FOUND")
            audio_files.append(None)
    
    if found_count == 0:
        print(f"  ERROR: No audio files found for {soundpack_name}")
        return False
    
    # Build ffmpeg command to concatenate audio with silence between
    output_file = OUTPUT_DIR / f"{soundpack_name}_combined.ogg"
    
    # Create a text file for ffmpeg concat demuxer
    concat_file = OUTPUT_DIR / f"concat_{soundpack_name}.txt"
    
    try:
        with open(concat_file, 'w') as f:
            # Add files and silence between them
            for i, audio_file in enumerate(audio_files):
                if audio_file:
                    # Escape file path for Windows
                    escaped_path = audio_file.replace("\\", "/")
                    f.write(f"file '{escaped_path}'\n")
                    
                    # Add 0.25 seconds of silence after each file (except the last)
                    if i < len(audio_files) - 1:
                        silence_file = OUTPUT_DIR / f"silence_0.25s.wav"
                        # Create silence file if needed
                        f.write(f"file '{silence_file}'\n")
        
        # First, we need to create a 0.25-second silence file if it doesn't exist
        silence_file = OUTPUT_DIR / "silence_0.25s.wav"
        if not silence_file.exists():
            print(f"  Creating silence file...")
            silence_cmd = [
                "ffmpeg", "-y", "-f", "lavfi",
                "-i", "anullsrc=r=44100:cl=mono,atrim=0:0.25",
                "-q:a", "9",
                str(silence_file)
            ]
            subprocess.run(silence_cmd, check=True, capture_output=True)
        
        # Now use proper filter to concat with silence between
        # Build input files and filter
        cmd = ["ffmpeg", "-y"]
        input_count = 0
        filter_parts = []
        
        for i, audio_file in enumerate(audio_files):
            if audio_file:
                cmd.extend(["-i", audio_file])
                filter_parts.append(f"[{input_count}]")
                input_count += 1
                
                # Add silence after this audio (except the last)
                if i < len(audio_files) - 1:
                    cmd.extend(["-i", str(silence_file)])
                    filter_parts.append(f"[{input_count}]")
                    input_count += 1
        
        # Build concat filter
        filter_str = "".join(filter_parts) + f"concat=n={input_count}:v=0:a=1[out]"
        
        cmd.extend([
            "-filter_complex", filter_str,
            "-map", "[out]",
            "-q:a", "9",
            str(output_file)
        ])
        
        print(f"  Running ffmpeg...")
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            print(f"  - ffmpeg error: {result.stderr}")
            return False
        
        print(f"  + Created {output_file.name}")
        return True
        
    except Exception as e:
        print(f"  - Error: {e}")
        return False
    finally:
        # Clean up concat file
        if concat_file.exists():
            try:
                concat_file.unlink()
            except:
                pass

# Process all soundpacks
soundpacks = [
    "RRFSounds",
    "Otopack",
    "ChestOldTimey",
    "ChestHoleCC",
    "ChestHole",
    "CDDA-Soundpack",
    "@'s soundpack",
    "BeepBoopBip",
    "CO.AG-music-only",
    "CC-Sounds-sfx-only",
    "CC-Sounds"
]

print("=" * 60)
print("SOUNDPACK COMBINATION TOOL")
print("=" * 60)

success_count = 0
fail_count = 0

for soundpack in soundpacks:
    soundpack_path = SOUND_DIR / soundpack
    if soundpack_path.exists():
        if create_combined_audio(soundpack, soundpack_path):
            success_count += 1
        else:
            fail_count += 1
    else:
        print(f"- Soundpack not found: {soundpack}")
        fail_count += 1

print("\n" + "=" * 60)
print(f"SUMMARY: {success_count} successful, {fail_count} failed")
print("=" * 60)
