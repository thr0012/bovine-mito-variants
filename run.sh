#!/usr/bin/env bash
set -euo pipefail

SRR=SRR33165226
NREADS=4000000
REF_ACC=NC_006853.1

mkdir -p data work out

# 1. Referencia (accession versionada)
curl -s "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=${REF_ACC}&rettype=fasta&retmode=text" > data/ref.fa

# 2. Primeiros N spots do run (deterministico, sem gzip)
fastq-dump -X ${NREADS} --split-files -O data ${SRR}

# 3. Trimagem (1 thread; relatorios ficam fora dos outputs)
fastp -w 1 -i data/${SRR}_1.fastq -I data/${SRR}_2.fastq \
      -o work/c1.fq -O work/c2.fq -j work/fastp.json -h work/fastp.html

# 4. Mapeamento
bwa index data/ref.fa
bwa mem -t 1 -K 100000000 -R '@RG\tID:s1\tSM:s1' data/ref.fa work/c1.fq work/c2.fq \
  | samtools sort -@ 1 -o work/aln.bam -
samtools index work/aln.bam

# 5. Metricas
samtools flagstat work/aln.bam > out/flagstat.txt
samtools coverage work/aln.bam > out/coverage.tsv

# 6. Variantes (haploide, sem cabecalho, que traz comando e data)
bcftools mpileup -f data/ref.fa -Ou work/aln.bam \
  | bcftools call -mv --ploidy 1 -Ov \
  | bcftools view -H > out/variants.tsv

# 7. Checksums
sha256sum data/ref.fa data/${SRR}_1.fastq data/${SRR}_2.fastq out/* > CHECKSUMS.txt
