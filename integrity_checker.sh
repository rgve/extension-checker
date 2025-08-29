#!/usr/bin/env bash
#
# Purpose:
#   Perform lightweight integrity checks on common NGS file types before they
#   enter downstream pipelines. Exactly ONE line per file is printed:
#     [OK] / [WARNING] / [ERROR] <TYPE> <PATH> - <message>
#
# Checks implemented
#   • FASTQ : extract the first 40 000 lines and run fastQValidator
#   • BAM   : inspect the first 500 header lines and verify the BAM EOF marker
#   • CRAM  : inspect the first 500 header lines and report missing reference
#             MD5 (M5) tags (warning)
#   • VCF   : parse the header plus the first 10 000 variant records with
#             bcftools head (fatal parse ⇒ ERROR)
#
# Exit status
#   • Any ERROR terminates execution immediately (set -e).
#   • WARNING is non-fatal (e.g., missing helper tool); processing continues.
#   • OK indicates the file passed the implemented checks.
# ---------------------------------------------------------------------------

set -e  # abort on command failure

FASTQ_LINES=40000      # FASTQ lines inspected
BAM_EOF_BYTES=32768    # bytes read from end of BAM for EOF validation
VCF_RECORDS=10000      # VCF/BCF records parsed

ok()   { echo "[OK] $1 $2 - $3"; }
warn() { echo "[WARNING] $1 $2 - $3"; }
err()  { echo "[ERROR] $1 $2 - $3"; exit 1; }

##############################################################################
# FASTQ
##############################################################################
check_fastq() {
    local f="$1" type="FASTQ"
    local tmp; tmp=$(mktemp)

    case "$f" in
        *.gz)  gunzip -c "$f" | head -n "$FASTQ_LINES" > "$tmp" ;;
        *)     head    -n "$FASTQ_LINES" "$f"         > "$tmp" ;;
    esac

    if ! command -v fastQValidator >/dev/null 2>&1; then
        rm -f "$tmp"
        warn "$type" "$f" "fastQValidator not found; FASTQ check skipped"
        return
    fi

    if fastQValidator --file "$tmp" --maxErrors 1 --disableSeqIDCheck >/dev/null 2>&1; then
        rm -f "$tmp"
        ok "$type" "$f" "validator passed on first ${FASTQ_LINES} lines"
    else
        rm -f "$tmp"
        err "$type" "$f" "fastQValidator reported format problems"
    fi
}

##############################################################################
# BAM
##############################################################################
check_bam() {
    local f="$1" type="BAM"

    if ! command -v samtools >/dev/null 2>&1; then
        warn "$type" "$f" "samtools not found; BAM check skipped"
        return
    fi

    # Header presence
    if ! samtools view -H "$f" 2>/dev/null | head -n 500 | grep -Eq '^@HD|^@SQ'; then
        err "$type" "$f" "header missing @HD/@SQ"
    fi

    # EOF marker
    local tail_tmp; tail_tmp=$(mktemp)
    tail -c "$BAM_EOF_BYTES" "$f" > "$tail_tmp" 2>/dev/null || true
    if ! xxd -p "$tail_tmp" | grep -iq '42430200'; then
        rm -f "$tail_tmp"
        err "$type" "$f" "BAM EOF magic (42430200) not found"
    fi
    rm -f "$tail_tmp"

    ok "$type" "$f" "header OK; EOF magic present"
}

##############################################################################
# CRAM
##############################################################################
check_cram() {
    local f="$1" type="CRAM"

    if ! command -v samtools >/dev/null 2>&1; then
        warn "$type" "$f" "samtools not found; CRAM check skipped"
        return
    fi

    # Header presence
    if ! samtools view -H "$f" 2>/dev/null | head -n 500 | grep -Eq '^@HD|^@SQ'; then
        err "$type" "$f" "header missing @HD/@SQ"
    fi

    # Reference MD5 tags (warning if absent)
    if samtools view -H "$f" 2>/dev/null | grep -q 'M5:'; then
        ok "$type" "$f" "header OK; M5 tags present"
    else
        warn "$type" "$f" "header OK; missing M5 reference MD5 tags"
    fi
}

##############################################################################
# VCF / BCF
##############################################################################
check_vcf() {
    local f="$1" type="VCF/BCF"

    if ! command -v bcftools >/dev/null 2>&1; then
        warn "$type" "$f" "bcftools not found; VCF/BCF check skipped"
        return
    fi

    if bcftools head -n "$VCF_RECORDS" "$f" >/dev/null 2>&1; then
        ok "$type" "$f" "bcftools parsed header + first ${VCF_RECORDS} records"
    else
        err "$type" "$f" "bcftools failed parsing within first ${VCF_RECORDS} records"
    fi
}

##############################################################################
# Main
##############################################################################
for file in "$@"; do
    if [[ ! -f "$file" ]]; then
        warn "FILE" "$file" "not found; skipping"
        continue
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
            warn "FILE" "$file" "unsupported extension; skipping" ;;
    esac
done
