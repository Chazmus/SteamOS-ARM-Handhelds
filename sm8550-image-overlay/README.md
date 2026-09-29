Files that only go into the 8 Gen 2 (SM8550) image. `sm8550-overlay/` is
installed on every image and matches devices at runtime; this one is copied
by apply-overlays.sh only when SOC=sm8550, so the 8 Gen 3 images never see it.
