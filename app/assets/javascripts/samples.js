function refreshSampleNameField(selected_sample, forceoverwrite){
	forceoverwrite = defaultValue(forceoverwrite, false);
	
	vcf_file_name = $("#sample_vcf_file_id option:selected", $(selected_sample).parent().parent()).text();
	sample_name = $(selected_sample).val();
	if (sample_name != ""){
		samplenamefield = $("#sample_name", $(selected_sample).parent().parent().parent());
		samplenicknamefield = $("#sample_nickname", $(selected_sample).parent().parent().parent());
		samplepatientfield = $("#sample_patient", $(selected_sample).parent().parent().parent());
		if ($(samplenamefield).val() == "" || forceoverwrite){
			$(samplenamefield).attr("value", $.trim(vcf_file_name).replace(" ", "_") + 
																 "/" + $.trim(sample_name).replace(" ", "_"))
												.effect( "highlight" );
			$(samplenicknamefield).attr("value", $.trim(sample_name).replace(" ", "_"))
												.effect( "highlight" );
		}
		if ($(samplepatientfield).val() == "" || forceoverwrite){
			$(samplepatientfield).attr("value", $.trim(sample_name).replace(" ", "_").replace(/[a-z]/g, "")).effect( "highlight" );
		}
	}
}

function refreshVcfSampleNames(resourceid){
		if (resourceid != ""){
			resource = $("#sample_vcf_file_id").attr("data-source");
			// resource = resource.replace(/-1/,resourceid);
			console.log(resourceid);
			console.log(resource);
			$.ajax({
			  url:resource,
			  data: {vcf_file_id: resourceid},
		  	dataType: "json", 
				success: jQuery.proxy(function(data, status, jqXHR){
					console.log(data);
					// clear sample name field and add empty option
					$("#sample_vcf_sample_name").removeAttr("disabled");
					$("#sample_vcf_sample_name").html("");
					$("<option/>").val("").text("").appendTo("#sample_vcf_sample_name");
					$.each(data, function(smplname, claimable){
						if (smplname != "_filters"){ // _filters is reserved to set the avaiable filter fields.
							backgroundcolor = "white";
							if (claimable){
								backgroundcolor = "lightblue";
							}
							$("<option/>").val(smplname)
														.text(smplname)
														.css("background-color", backgroundcolor)
														.appendTo("#sample_vcf_sample_name");
						}
					});
					setAvailableFilters(data["_filters"]);
				}, $(this))
			});
		}
}

// this function refreshes the available filters checkboxes when a new VCF is loaded
function setAvailableFilters(filters){
	$("#available_filters").html("");
	$.each(filters, function(filterval, numfilter){
		chked = ""
		if (filterval == "PASS"){
			chked = "checked"
		}
		$("#available_filters").append("<input value='" + filterval + "' " + chked + " type=checkbox name='sample[filters][]'>" + filterval + " (" + numfilter + ")<br>");
	});
}




function refreshVcfSampleNames_old(resourceid){
	console.log("refresh sample name");
	if (resourceid != ""){
		resource = $("#sample_vcf_file_id").attr("data-source");
		resource = resource.replace(/-1/,resourceid);
		$.ajax({
					  url:resource,
					  data: {content: 0},
				  	dataType: "json", 
						success: jQuery.proxy(function(data, status, jqXHR){
							// now make another request to see which samples 
							// of the vcf file were already added to the database
							smplname_in_use = {};
							console.log(resourceid);
							jQuery.ajax({
								url: "/samples",
								data: {vcf_file_id: resourceid, format: "json"},
								dataType: "json",
								async: false,
								success: function(data, status, jqXHR){
									smpls_of_vcf = $.makeArray(data);
									$(smpls_of_vcf).each(function(smpli){
										smplname_in_use[smpls_of_vcf[smpli]["vcf_sample_name"]] = true;
									});
								}
							});
							smplnames = data["sample_names"];
							$("#sample_vcf_sample_name").removeAttr("disabled");
							$("#sample_vcf_sample_name").html("");
							// add empty sample name
							$("<option/>").val("").text("").appendTo("#sample_vcf_sample_name");
							if (smplnames.length > 0){
								for (reci in smplnames){
									backgroundcolor = "white";
									if (! smplname_in_use[smplnames[reci]]){
										backgroundcolor = "lightblue";
									}
									$("<option/>").val(smplnames[reci])
																.text(smplnames[reci])
																.css("background-color", backgroundcolor)
																.appendTo("#sample_vcf_sample_name");
								}
							}
						}, $(this))
				});
	} else {
		resource = "";
		$("#sample_vcf_sample_name").html("");
		$("<option/>").val("").text("Please select a VCF file").appendTo("#sample_vcf_sample_name");
		$("#sample_vcf_sample_name").attr("disabled", "disabled");		
	}
	return(resource);
};

var tmp;
$(document).ready(function() {
	if ($("#sample_vcf_sample_name").val() == null){
		if (isDefined($("#sample_vcf_file_id").val())){
			refreshVcfSampleNames($("#sample_vcf_file_id").val());
		}
	} else {
		refreshSampleNameField($("#sample_vcf_sample_name"), false);
	}
	// register ignorefilter click event so all available filters are selected if the box is checked
	// this should make everything more consistent
	$("#sample_ignorefilter").click(function(){
		ischked = $("#sample_ignorefilter").is(":checked");
		$("input:checkbox", "#available_filters").each(function(){
			this.checked = ischked;
		});
	});
	$("input:checkbox", "#available_filters").click(function(){
		if (!$(this).is(":checked")){
			$("#sample_ignorefilter").prop("checked", false);
		}
	});
});