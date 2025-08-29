# Multi‑format File Integrity Checker

This Bash script provides lightweight and rapid integrity checks for common next-generation sequencing (NGS) data files, enabling early detection of problematic or corrupted files prior to downstream bioinformatics analysis.

## Purpose

- Quickly identify corrupt or improperly formatted genomic data files.
- Ensure basic file format compliance, significantly reducing the risk of pipeline failure.

## How it works

1. Detects file type from the extension.
2. Runs a lightweight check tailored to that format:

   * **FASTQ** → sample first 40 000 lines → `fastQValidator`
   * **BAM** → header sanity check + EOF signature
   * **CRAM** → header sanity check + MD5 presence
   * **VCF/BCF** → header + first 10 000 records via `bcftools`
  
Each file produces a single summary line of output.

## Supported file types

### 1. FASTQ (`.fastq`, `.fastq.gz`, `.fq`, `.fq.gz`)

- Extracts the first **40,000 lines** (~10,000 reads in typical paired-end sequencing).
- Performs validation using `fastQValidator` to detect critical formatting errors.
- Output:
  - `[OK]` if validator passes
  - `[ERROR]` if validator detects problems
  - `[WARNING]` if `fastQValidator` is missing (check skipped)

### 2. BAM (`.bam`, `.bam.gz`)

- Inspects the first **500 header lines** using `samtools` to confirm presence of essential tags (`@HD` and/or `@SQ`).
- Verifies presence of the BAM-specific EOF marker (`42430200`) within the last 32 KB, ensuring the file isn't truncated.
- Output:
  - `[OK]` if header and EOF marker are valid
  - `[ERROR]` if header is malformed or EOF marker is missing
  - `[WARNING]` if `samtools` is missing

### 3. CRAM (`.cram`, `.cram.gz`)

- Checks the first **500 header lines** using `samtools` for essential header tags (`@HD` and/or `@SQ`).
- Verifies presence of reference **MD5 checksum (M5)** tags in the header.
- Output:
  - `[OK]` if header and M5 tags are present
  - `[ERROR]` if M5 tags are missing
  - `[ERROR]` if header is invalid
  - `[WARNING]` if `samtools` is missing

### 4. VCF/BCF (`.vcf`, `.vcf.gz`, `.bcf`, `.bcf.gz`, `.vcf.bz2`, `.bcf.bz2`)

- Parses the file header and the first **10,000 variant records** using `bcftools head`.
- Rapidly identifies fatal syntax, format, or specification errors.
- Output:
  - `[OK]` if parsing succeeds
  - `[ERROR]` if parsing fails
  - `[WARNING]` if `bcftools` is missing

## Dependencies

| Tool                                                          | Purpose                |
| ------------------------------------------------------------- | ---------------------- |
| **bash** ≥4                                                   | scripting language     |
| GNU **coreutils** (`head`, `tail`, `grep`, `xxd`)             | basic ops              |
| [`fastQValidator`](https://github.com/statgen/fastqvalidator) | FASTQ validation       |
| [`samtools`](https://www.htslib.org/)                         | BAM/CRAM header checks |
| [`bcftools`](https://www.htslib.org/)                         | VCF/BCF parsing        |

Ensure each tool is on your `$PATH`.

## Usage

```bash
chmod +x quick_check.sh
./quick_check.sh file1.fastq.gz file2.bam file3.vcf.gz
```

The script auto‑detects the format and prints status messages for each file.

### Sample output

```text
[OK] FASTQ file1.fastq.gz - validator passed on first 40000 lines
[OK] BAM file2.bam - header OK; EOF magic present
[OK] VCF/BCF file3.vcf.gz - bcftools parsed header + first 10000 records
```

## Exit status and log messaging

| Status       | Description                                                             |
| ------------ | ----------------------------------------------------------------------- |
| `[OK]`       | File passed all checks.                                                 |
| `[WARNING]`  | Recommended software not available.                                     |
| `[ERROR]`    | Fatal issue; script terminates immediately.                             |

A pass indicates that the *sampled portion* is valid; it does **not** guarantee that the entire file is error‑free.

##  Limitations

* Only partial validation for speed, deep‑file corruption may go unnoticed.
* Default thresholds can be adjusted in the script:
* Validates only selected sections of the file:
   *40k FASTQ lines
   *500 BAM/CRAM header lines
   *10k VCF records
