Features

BAM/CRAM checker:
* Header sanity check – confirms presence of @HD or @SQ tags.
* CRAM reference checksum – warns when M5: MD5 tags are missing from any @SQ line.
* BAM EOF – verifies the BGZF EOF marker (42 43 02 00) to catch truncated uploads.
* Partial‑read design – only inspects the first 500 header lines and the last TAIL_SIZE bytes (default 28), so it can run on a a huge BAM/CRAM file.
