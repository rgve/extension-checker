# Multi‑format File Integrity Checker

This Bash script provides lightweight and rapid integrity checks for common next-generation sequencing (NGS) data files, enabling early detection of problematic or corrupted files prior to downstream bioinformatics analysis.

## Purpose

- Quickly identify corrupt or improperly formatted genomic data files.
- Ensure basic file format compliance, significantly reducing the risk of pipeline failure.

## How it works

1. Detects file type from the extension.
2. Runs a targeted validation routine:

   * **FASTQ** → sample first 40 000 lines → `fastQValidator`
   * **BAM** → header sanity check + EOF signature
   * **CRAM** → header sanity check (+ optional MD5 warning)
   * **VCF/BCF** → header + first 10 000 records via `bcftools`

## Supported file types

### 1. FASTQ (`.fastq`, `.fastq.gz`)

- Extracts the first **40,000 lines** (~10,000 reads in typical paired-end sequencing).
- Performs validation using `fastQValidator` to detect critical formatting errors.
- Reports `[OK]` on successful validation.
- Issues `[WARNING]` if `fastQValidator` is unavailable.

### 2. BAM (`.bam`, `.bam.gz`)

- Inspects the first **500 header lines** using `samtools` to confirm presence of essential tags (`@HD` and/or `@SQ`).
- Verifies presence of the BAM-specific EOF marker (`42430200`) within the last 32 KB, ensuring the file isn't truncated.
- Reports `[OK]` if both checks pass.
- Reports `[ERROR]` and aborts immediately if any critical issue is found.

### 3. CRAM (`.cram`, `.cram.gz`)

- Checks the first **500 header lines** using `samtools` for essential header tags (`@HD` and/or `@SQ`).
- Verifies presence of reference **MD5 checksum (M5)** tags in the header.
  - Issues `[WARNING]` if MD5 checksum tags are missing.
- Reports `[OK]` if essential header tags are present.
- Reports `[ERROR]` and aborts immediately if critical header tags are absent.

### 4. VCF/BCF (`.vcf`, `.vcf.gz`, `.bcf`, `.bcf.gz`, `.vcf.bz2`, `.bcf.bz2`)

- Parses the file header and the first **10,000 variant records** using `bcftools head`.
- Rapidly identifies fatal syntax, format, or specification errors.
- Reports `[OK]` if parsing is successful.
- Reports `[ERROR]` and aborts immediately upon detecting critical parsing issues.

## Dependencies

| Tool                                                          | Purpose                |
| ------------------------------------------------------------- | ---------------------- |
| **bash** ≥4                                                   | scripting language     |
| GNU **coreutils** (`head`, `tail`, `grep`, `xxd`)             | basic ops              |
| [`fastQValidator`](https://github.com/statgen/fastqvalidator) | FASTQ validation       |
| [`samtools`](https://www.htslib.org/)                         | BAM/CRAM header checks |
| [`bcftools`](https://www.htslib.org/)                         | VCF/BCF parsing        |

Ensure each tool is on your `$PATH`.

## Quick start

```bash
# make the script executable
chmod +x integrity_checker.sh

# validate one or more files
./integrity_checker.sh sample.fastq.gz variants.vcf.gz alignments.bam
```

The script auto‑detects the format and prints status messages for each file.

### Sample output

```text
----------------------------------
Processing file: sample.fastq.gz
[FASTQ] Validating first 40000 lines of 'sample.fastq.gz'...
Running fastQValidator...
[OK] FASTQ check passed.

----------------------------------
Processing file: alignments.bam
[BAM/CRAM] Validating 'alignments.bam'...
[OK] BAM header and EOF marker validated.

----------------------------------
Processing file: variants.vcf.gz
[VCF] Validating header plus first 10000 records of 'variants.vcf.gz' with bcftools...
[OK] bcftools parsed the header and first 10000 records without fatal errors.
```

## Exit status and log messaging

| Status       | Description                                                             |
| ------------ | ----------------------------------------------------------------------- |
| `[OK]`       | File passed all validation checks successfully.                         |
| `[WARNING]`  | Non-critical issues detected, or recommended software not available.    |
| `[ERROR]`    | Critical validation errors detected; script execution aborted.          |

A pass indicates that the *sampled portion* is valid; it does **not** guarantee that the entire file is error‑free.

##  Limitations

* Only partial validation for speed, deep‑file corruption may go unnoticed.
* Default thresholds (40 k lines, 10 k records, last 32 KB) can be adjusted in the script.
* Custom or non‑standard BAM/CRAM layouts may trip the EOF check.
