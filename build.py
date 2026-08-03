import os
import subprocess
import sys

def build():
    # 1. Create build directory safely
    os.makedirs("build", exist_ok=True)

    print("--- 1/2: Configuring CMake ---")
    config_result = subprocess.run(["cmake", "-B", "build", ".", "-DCMAKE_BUILD_TYPE=Release"])
    if config_result.returncode != 0:
        print("Error: CMake configuration failed. Make sure CMake and a compiler are installed.")
        sys.exit(1)

    print("\n--- 2/2: Building C++ Target ---")
    build_result = subprocess.run(["cmake", "--build", "build", "--config", "Release"])
    if build_result.returncode != 0:
        print("Error: Compilation failed.")
        sys.exit(1)

    print("\nBuild successful")

if __name__ == "__main__":
    build()