function basename(path) {
    return path.replace(/\\/g,'/').replace( /.*\//, '' );
}

var vcf_replacements = {
	ref: new RegExp("[-._]*ref", 'ig'),
	wgs: new RegExp("[-._]*wgs", 'ig'),
	merged: new RegExp("[-._]*merged", 'ig'),
	cmpl: new RegExp("[-._]*cmpl", 'ig'),
	variants: new RegExp("[-._]*variants", 'ig'),
	cln: new RegExp("[-._]*cln", 'ig'),
	keep: new RegExp("[-._]*keep", 'ig'),
	hc: new RegExp("[-._]*hc", 'ig'),
	fib: new RegExp("[-._]*fib", 'ig'),
	snps: new RegExp("[-._]*snps", 'ig'),
	annot: new RegExp("[-._]*annot", 'ig'),
	relax: new RegExp("[-._]*relax", 'ig'),
	gz: new RegExp("[-._]*gz", 'ig'),
	calls: new RegExp("[-._]*calls", 'ig'),
	annotated: new RegExp("[-._]*annotated", 'ig'),
	all: new RegExp("[-._]*all", 'ig'),
	//ptp: new RegExp("[-._]*ptp", 'ig'),
	filtered: new RegExp("[-._]*filtered", 'ig'),
	indels: new RegExp("[-._]*indels", 'ig'),
	//mutect: new RegExp("[-._]*mutect", 'ig'),
	//varscan2: new RegExp("[-._]*varscan2", 'ig'),
	somatic: new RegExp("[-._]*somatic", 'ig'),
	//gatk: new RegExp("[-._]*gatk", 'ig'),
	srt: new RegExp("[-._]*srt", 'ig'),
	nodup: new RegExp("[-._]*nodup", 'ig'),
	real: new RegExp("[-._]*real", 'ig'),
	recal: new RegExp("[-._]*recal", 'ig'),
	indel: new RegExp("[-._]*indel", 'ig'),
	snp: new RegExp("[-._]*snp", 'ig'),
	vcf: new RegExp("[-._]*vcf", 'ig'),
	rehead: new RegExp("[-._]*rehead", 'ig')
};

function updateVcfName(filefield){
	filename = basename($(filefield).val()).replace(/.vcf$/, "");
	
	vcfname = $('input[name*="name"]', $(filefield).closest("tr")).first();
	vcfprefix = $("#vcf_file_name_prefix").val();
	
	$.each(vcf_replacements, function(k,v){
		filename = filename.replace(v, "");
	});
	
	if (vcfprefix != ""){
		$(vcfname).attr("value", vcfprefix + "/" + filename);
	} else {
		$(vcfname).attr("value", filename);
	}
	$(vcfname).effect("highlight", {}, 1000);
	true;
}

function updateSampleName(filefield){
	filepath = $(filefield).val();
	filename = basename(filepath).replace(/.vcf$/, "");
		
	sampleprefix = $("#vcf_file_name_prefix").val();
	// samplename = sampleprefix + filename.split(".")[0];
	// if the filename follows the convention "sample1.tool1.tool2-sample2.toool1.tool3.filter.vcf"
	// then the predicted samplename will be "sample1-sample2"
	filename_elements = $.makeArray(filename.split("-"));
	samplename = sampleprefix + $.map(filename_elements, function(val, i){return(val.split(".")[0]);}).join("-");
	
	if (filename.toLowerCase().indexOf("somatic") >= 0){
		samplename = samplename + "_somatic";
	}
	if (filename.toLowerCase().indexOf("germline") >= 0){
		samplename = samplename + "_germline";
	}
	if (filename.toLowerCase().indexOf("mutect") >= 0){
		samplename = samplename + "_mutect";
	}
	if (filename.toLowerCase().indexOf("varscan") >= 0){
		samplename = samplename + "_varscan";
	}
	
	namefield = $("#vcf_file__name", $(filefield).parent().parent());
	if ($(namefield.first()).val() == ""){
		$(namefield.first()).attr("value", samplename);
		$(namefield.first()).effect("highlight", {}, 1000);
	} else {
		$(namefield.first()).attr("value", samplename);
		$(namefield.first()).effect("highlight", {color: "steelblue"}, 2500);
	}
}

function updateContact(field, hl){
	contacts = $('input[name=vcf_file\\[\\]\\[contact\\]]');
	myidx = contacts.index(field);
	if (hl){
		contacts.slice(myidx).attr("value", $(field).val()).effect("highlight", {}, 500);
	} else {
		contacts.slice(myidx).attr("value", $(field).val());
	}
	
}
