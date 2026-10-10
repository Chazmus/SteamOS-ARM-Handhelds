Files that only go into the 865 (SM8250) image: audio (UCM, WirePlumber),
InputPlumber profiles, udev rules and the steamos-manager device list for the
Retroid Pocket 5 / Flip 2 / Mini / Mini V2, AYN Thor Lite, MANGMI Air Y Pro
/ Pocket Max and AYANEO Pocket MICRO 2. apply-overlays.sh copies them only when SOC=sm8250 and removes
them from a reused rootfs otherwise.
