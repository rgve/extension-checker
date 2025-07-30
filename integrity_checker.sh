#!/usr/bin/env bash
#
# Purpose:
#   Perform lightweight integrity checks on common NGS file types before they
#   enter downstream pipelines.
#
# Checks implemented
#   • FASTQ : extract the first 40 000 lines and run fastQValidator
#   • BAM   : inspect the first 500 header lines and verify the BAM EOF marker
#   • CRAM  : inspect the first 500 header lines and report missing reference
#             MD5 (M5) tags
#   • VCF   : parse the header plus the first 10 000 variant records with
#             bcftools head
#
# Exit status
#   • Any [ERROR] message terminates execution immediately (set -e).
#   • [WARNING] messages report non-fatal issues.
#   • [FAIL] messages report missing software.
#   • [OK] messages indicate that the file passed the implemented checks.
#
# ---------------------------------------------------------------------------

set -e  # abort on command failure

FASTQ_LINES=40000      # FASTQ lines inspected
BAM_EOF_BYTES=32768    # bytes read from end of BAM for EOF validation
VCF_RECORDS=10000      # VCF/BCF records parsed

##############################################################################
# FASTQ
##############################################################################
check_fastq() {
    local f="$1"
    echo "[FASTQ] $f"

    local tmp
    tmp=$(mktemp)

    case "$f" in
        *.gz)  gunzip -c "$f" | head -n "$FASTQ_LINES" > "$tmp" ;;
        *)     head    -n "$FASTQ_LINES" "$f"         > "$tmp" ;;
    esac

    if ! command -v fastQValidator >/dev/null; then
        echo "  [FAIL] fastQValidator not found; FASTQ validation skipped."        rm -f "$tmp"
        return
    fi

    if fastQValidator --file "$tmp" --maxErrors 1 --disableSeqIDCheck; then
        echo "  [OK] fastQValidator completed without critical errors."
    else
        echo "  [ERROR] fastQValidator reported format problems."
        rm -f "$tmp"
        exit 1
    fi
    rm -f "$tmp"
}


##############################################################################
# BAM
##############################################################################
check_bam() {
    local f="$1"
    echo "[BAM] $f"

    if ! command -v samtools >/dev/null; then
        echo "  [FAIL] samtools not found; BAM validation skipped."        return
    fi

    # Header presence
    if ! samtools view -H "$f" | head -n 500 | grep -Eq '^@HD|^@SQ'; then
        echo "  [ERROR] Header does not contain @HD or @SQ tags."
        exit 1
    fi

    # EOF marker
    local tail_tmp
    tail_tmp=$(mktemp)
    tail -c "$BAM_EOF_BYTES" "$f" > "$tail_tmp" || true
    if ! xxd -p "$tail_tmp" | grep -iq '42430200'; then
        echo "  [ERROR] BAM EOF marker (42430200) not detected."
        exit 1
    fi
    rm -f "$tail_tmp"

    echo "  [OK] Header and EOF marker verified."
}

##############################################################################
# CRAM
##############################################################################
check_cram() {
    local f="$1"
    echo "[CRAM] $f"

    if ! command -v samtools >/dev/null; then
        echo "  [FAIL] samtools not found; CRAM validation skipped."        return
    fi

    # Header presence
    if ! samtools view -H "$f" | head -n 500 | grep -Eq '^@HD|^@SQ'; then
        echo "  [ERROR] Header does not contain @HD or @SQ tags."
        exit 1
    fi

    # Reference MD5 tags
    if ! samtools view -H "$f" | grep -q 'M5:'; then
        echo "  [WARNING] Reference M5 checksum tags are absent."
    fi

    echo "  [OK] Header verified."
}

##############################################################################
# VCF / BCF
##############################################################################
check_vcf() {
    local f="$1"
    echo "[VCF/BCF] $f"

    if ! command -v bcftools >/dev/null; then
        echo "  [FAIL] bcftools not found; VCF/BCF validation skipped."        return
    fi

    if bcftools head -n "$VCF_RECORDS" "$f" > /dev/null 2>&1; then
        echo "  [OK] bcftools parsed the header and first $VCF_RECORDS records."
    else
        echo "  [ERROR] bcftools failed while parsing the file."
        exit 1
    fi
}

##############################################################################
# Main
##############################################################################
for file in "$@"; do
    if [[ ! -f "$file" ]]; then
        echo "[FAIL] '$file' not found; skipping."        continue
    fi

    case "$file" in
        *.fastq|*.fastq.gz|*.fq|*.fq.gz)
            check_fastq "$file" ;;
        *.bam|*.bam.gz)
            check_bam "$file" ;;
        *.cram|*.cram.gz)
            check_cram "$file" ;;
        *.vcf|*.vcf.gz|*.bcf|*.bcf.gz|*.vcf.bz2|*.bcf.bz2)
            check_vcf "$file" ;;
        *)
            echo "[FAIL] '$file' has an unsupported extension; skipping." ;;    esac

    echo
done

echo "Files validation completed."
