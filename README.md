# Bovine mitochondrial variant calling (Angus WGS subset)

Calls variants in the mitochondrial genome of an Angus calf against the
*Bos taurus* reference mitogenome (NC_006853.1), using the first 4,000,000
read pairs of a public WGS run.

## Data (not included, fetched by run.sh)

- Reads: SRA run SRR33165226 (BioProject PRJNA1245396, USDA ARS USMARC),
  Illumina paired-end, 2x151 bp, WGS of fibroblasts from cloned Angus calves.
  Only the first 4,000,000 spots are used (`fastq-dump -X 4000000`), so the
  subset may not represent the whole run.
- Reference: NCBI nuccore NC_006853.1 (via efetch).

## Requirements

Linux or WSL, conda/miniforge, internet access, about 10 GB free disk.

## Setup

    conda env create -f environment.yml
    conda activate bovine-mito

`environment.yml` pins the five tools (sra-tools 3.4.1, fastp 1.3.7,
bwa 0.7.19, samtools 1.24, bcftools 1.24). `environment.lock.yml` is the exact
export of the environment used, including indirect dependencies.

## Run

    bash run.sh

Expected time: about 10 minutes on a laptop (1 thread).

## Methods (steps in order)

1.  Download the reference FASTA (NC_006853.1) from NCBI efetch
   curl -s "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=NC_006853.1&rettype=fasta&retmode=text" | head -c 100
2. Download the first 4,000,000 read pairs of SRR33165226 with fastq-dump
   (--split-files, uncompressed).
3. Trim adapters and low-quality bases with fastp (1 thread, default settings).
4. Map trimmed reads to the reference with bwa mem (1 thread, -K 100000000),
   sort and index with samtools.
5. Summarize mapping with samtools flagstat and samtools coverage.
6. Call variants with bcftools mpileup and bcftools call (-mv, --ploidy 1);
   the VCF header is dropped (bcftools view -H) because it contains the
   command line and date.
7. Write sha256 checksums of the reference, both FASTQ files and all outputs
   to CHECKSUMS.txt.

## Expected output (out/)

- flagstat.txt: mapping summary
- coverage.tsv: one row, mean depth about 51x, 100% of the genome covered
- variants.tsv: 18 variant records, no header

Verify from the project root, after run.sh finishes:

    sha256sum -c CHECKSUMS.txt

## Notes

- bcftools prints "MQ should be declared as Type=Float". This is a header
  warning and does not affect the results.
- bwa prints "skip orientation ... not enough pairs" for some batches. This
  is expected with few mapped pairs.
- Reads from nuclear copies of mtDNA (NUMTs) can map to the mitogenome and
  produce spurious variants. No filtering was applied.
- The reads come from fibroblasts of cloned calves. In clones, mtDNA comes
  from the recipient oocyte, so it may not match the donor's maternal line.
- Reproducibility: run.sh was run three times on the same machine (once in
  the original folder, then twice in fresh folders using an environment
  rebuilt from environment.yml). All checksums were identical.
