#!/bin/bash

mkdir -p ./tmp
ls -1A | grep zip | while read file; do 
	bn=`basename $file .zip`;
	if [ ! -f "./$bn.bed" ];
	then
	    unzip $file -d tmp
	    mv tmp/*Regions.bed "./$bn.bed"
	    rm tmp/*
	fi
done

# generate the yaml entries
ls -1A | grep .bed | while read file; do 
name=`echo -n $file | sed 's/_S[0-9]*.bed//g'`
cat << EOS
  $name:
    description: $name extracted from AgilentSureDesign Platform.
    file: <%=CaptureKitAnnotation.config('capturekitdir')%>/bed_files/SureSelect/$file
    capture_type: exome_capture
    active: false
EOS

done

      AgilentHumanExomeV5plusUTR:
        description: Agilent V5 UTR kit
        file: <%=CaptureKitAnnotation.config('capturekitdir')%>/bed_files/agilent_humanexomev5_S04380219_Regions.bed
        capture_type: exome_capture
      AgilentHumanExomeV4plusUTR:
        description: Agilent V4 UTR kit
        file: <%=CaptureKitAnnotation.config('capturekitdir')%>/bed_files/agilent_human_exome4_UTR_S03723424_Regions.bed
        capture_type: exome_capture
      AgilentSureSelectHumanAllExonV6:
        description: Agilent V6 All Exon Kit
        file: <%=CaptureKitAnnotation.config('capturekitdir')%>/bed_files/Agilent_SureSelect_Human_AllExon_V6_r2.hGRC37.Covered.bed
        capture_type: exome_capture