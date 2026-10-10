"""
Constants for the lsfg-vk plugin.
"""

from pathlib import Path

LOCAL_LIB = ".local/lib"
LOCAL_SHARE_BASE = ".local/share"
VULKAN_LAYER_DIR = ".local/share/vulkan/implicit_layer.d"
CONFIG_DIR = ".config/lsfg-vk-classic"

SCRIPT_NAME = "lsfg-classic"
CONFIG_FILENAME = "conf.toml"
# Installed under their own names: the lsfg-vk 2.0 plugin deletes the 1.x
# files it finds under the original ones.
LIB_FILENAME = "liblsfg-vk-classic.so"
JSON_FILENAME = "VkLayer_LS_frame_generation_classic.json"
ZIP_LIB_FILENAME = "liblsfg-vk.so"
ZIP_JSON_FILENAME = "VkLayer_LS_frame_generation.json"
# The layer loads only into games started through ~/lsfg-classic.
ENABLE_ENV = "LSFG_CLASSIC"
ZIP_FILENAME = "lsfg-vk_noui.zip"

FLATPAK_23_08_FILENAME = "org.freedesktop.Platform.VulkanLayer.lsfg_vk_23.08.flatpak"
FLATPAK_24_08_FILENAME = "org.freedesktop.Platform.VulkanLayer.lsfg_vk_24.08.flatpak"
FLATPAK_25_08_FILENAME = "org.freedesktop.Platform.VulkanLayer.lsfg_vk_25.08.flatpak"

SO_EXT = ".so"
JSON_EXT = ".json"

BIN_DIR = "bin"

STEAM_COMMON_PATH = Path("steamapps/common/Lossless Scaling")
LOSSLESS_DLL_NAME = "Lossless.dll"

ENV_LSFG_DLL_PATH = "LSFG_DLL_PATH"
ENV_XDG_DATA_HOME = "XDG_DATA_HOME"
ENV_HOME = "HOME"

