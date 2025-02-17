# download transcriptome annotation
rule txome_gtf:
    input:
        FTP.remote(
            "ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_43/gencode.v43.basic.annotation.gtf.gz",
            static=True,
        ),
    output:
        "rnaseq/ref/txome.chr{chrom}.gtf",
    cache: "omit-software"
    shell:
        "gzip -dc {input} | grep ^chr{wildcards.chrom} > {output}"


# download repeatmasker annotation
rule rmsk_gtf:
    input:
        HTTP.remote(
            "https://labshare.cshl.edu/shares/mhammelllab/www-data/TEtranscripts/TE_GTF/GRCh38_GENCODE_rmsk_TE.gtf.gz",
            static=True,
        ),
    output:
        "rnaseq/ref/rmsk.chr{chrom}.gtf",
    cache: "omit-software"
    shell:
        "gzip -dc {input} | grep ^chr{wildcards.chrom} > {output}"


rule telocal_locInd:
    input:
        rules.rmsk_gtf.output,
    output:
        "rnaseq/ref/rmsk.chr{chrom}.gtf.locInd",
    conda:
        "../telocal.yaml"
    script:
        "../scripts/telocal_locInd.py"


# download genome fasta
rule genome_fa:
    input:
        FTP.remote(
            "ftp://hgdownload.soe.ucsc.edu/goldenPath/hg38/chromosomes/chr{chrom}.fa.gz",
            static=True,
            immediate_close=True,
        ),
    output:
        "rnaseq/ref/genome.chr{chrom}.fa",
    cache: "omit-software"
    shell:
        "gzip -dc {input} > {output}"


# download transcriptome fasta
rule txome_fa:
    input:
        fa=FTP.remote(
            "ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_43/gencode.v43.transcripts.fa.gz",
            static=True,
            immediate_close=True,
        ),
        gtf=rules.txome_gtf.output,
    output:
        multiext(
            "rnaseq/ref/",
            "names.chr{chrom}.lst",
            "txome.chr{chrom}.fa",
        ),
    conda:
        "../environment.yaml"
    shell:
        """
        grep -o 'ENST[0-9]*\.[0-9]' {input.gtf} | sort | uniq | awk '{{print $1".*"}}' > {output[0]}
        gzip -dc {input.fa} | seqkit grep -f {output[0]} -r > {output[1]}
        """


rule reads:
    input:
        FTP.remote(
            [
                "ftp.ebi.ac.uk/biostudies/fire/E-GEUV-/001/E-GEUV-1/Files/E-GEUV-1/processed/NA20778.4.M_120208_1.bam",
                "ftp.ebi.ac.uk/biostudies/fire/E-GEUV-/001/E-GEUV-1/Files/E-GEUV-1/processed/NA20778.4.M_120208_1.bam.bai",
            ],
            static=True,
            keep_local=True,
            immediate_close=True,
        ),
    output:
        bam="rnaseq/{sample}.chr{chrom}.bam",
        fq1="rnaseq/{sample}.chr{chrom}.1.fq.gz",
        fq2="rnaseq/{sample}.chr{chrom}.2.fq.gz",
    conda:
        "../environment.yaml"
    shell:
        """
        touch -m {input[1]}
        samtools view -b {input[0]} chr{wildcards.chrom} > {output.bam}
        samtools fastq -1 {output.fq1} -2 {output.fq2} -0 /dev/null -s /dev/null {output.bam}
        """


rule rnaseq:
    input:
        expand(
            [
                "rnaseq/ref/txome.chr{chrom}.gtf",
                "rnaseq/ref/genome.chr{chrom}.fa",
                "rnaseq/ref/txome.chr{chrom}.fa",
                "rnaseq/ref/rmsk.chr{chrom}.gtf",
                "rnaseq/ref/rmsk.chr{chrom}.gtf.locInd",
            ],
            chrom=21,
        ),
        expand(
            rules.reads.output,
            sample=["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l"],
            chrom=21,
        ),
