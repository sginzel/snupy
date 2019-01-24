var snupyPlots = {};
var myPlot;

var previousTooltipPoint = null;
function showPlotTooltip(x, y, contents) {
	$("<div id='plottooltip'>" + contents + "</div>").css({
		position: "absolute",
		display: "none",
		top: y + 5,
		left: x + 5,
		border: "1px solid #fdd",
		padding: "2px",
		"background-color": "#fee",
		opacity: 0.80
	}).appendTo("body").fadeIn(200);
}

function refreshPlotData(container, settingscontainer){
	labels = $("input:checked[class=plot_select]", settingscontainer).map(function(idx, elem){
		return($(elem).val());
	}).get();
	plot = snupyPlots[$(container).attr("id")];
	newData =  snupyplot_getData(container, labels);
	plot.setData(newData);
	plot.setupGrid();
	plot.draw();
}

var tmp;
// This function registers events to the checkboxes so all checkboxes 
// can be selected and the graph is refreshed on click events
function init_snupyplotsettings(container, settingscontainer){
	chkboxes = $("input:checkbox[class=plot_select]", settingscontainer);
	select_all = $("input:checkbox[class=plot_select_all]", settingscontainer);
	
	$(chkboxes).on("click", function(){
		container = $(".plot", $(this).closest(".plot_container"));
		settingscontainer = $(".snupyplotsettings", container.parent());
		refreshPlotData(container, settingscontainer);
	});
	
	$(select_all).on("change", function(){
		tmp = this;
		container = $(".plot", $(this).closest(".plot_container"));
		settingscontainer = $(".snupyplotsettings", container.parent());
		chkboxes = $("input:checkbox[class=plot_select]", settingscontainer);
		$(chkboxes).prop("checked", $(this).is(":checked"));
		refreshPlotData(container, settingscontainer);
	});
}

// this function converts the x,y notation into
// [[x1,y1], [x2,y2]...] notation
function snupyplot_getData(container, labels){
	container = defaultValue(container, $(".plot"));
	container_data = container.data("data");
	
	labels = defaultValue(labels, Object.keys(container_data));

	plotdata = [];
	for (i in labels){
		if (labels[i] != "plot" && labels[i] != "resizeSpecialEvent"){
			x = defaultValue(container_data[labels[i]]["x"], []);
			y = defaultValue(container_data[labels[i]]["y"], []);
			label = defaultValue(labels[i], "Unknown");
			
			// merge x and y
			if (x.length != y.length){
				throw "X and Y have to be the same length";
			}
			var data = [];
			for (var i=0; i<x.length; i++) {
				data[i] = [x[i], y[i]];
			}
			plotdata.push({
				label: label, 
				data: data
			});
		}
	}
	return(plotdata);
}

// This is where the plots happen
function snupyplot(container, labels){
	
	plotdata = snupyplot_getData(container, labels);
	
	opts = container.data("opts");
	height = defaultValue(opts["height"], 400);
	width = defaultValue(opts["width"], 600);
	points = defaultValue(opts["points"], true);
	lines = defaultValue(opts["lines"], true);
	$(container).height(height);
	$(container).width(width);
	$(container).parent().height(height);
	// add legend container
	// $(container).parent().append("<div id='snupylegend'>SNUPY LEGEND</div>");
	legend_container = $(".snupyplotlegend", container.parent());
	var plot = $.plot(
		container,
		plotdata,
		{
			series: {
						lines: { show: lines },
						points: { show: points }
			},
			grid: {					
				clickable: true,
    		hoverable: true,
    		autoHighlight: true
    },
    legend: {
    	container: legend_container//"#" + legendid
    }
		}
	);
	snupyPlots[$(container).attr("id")] = plot;

	$(container).bind("plothover", function (event, pos, item) {
		// thisplot = snupyPlots[$(this).attr("id")];
		if (item) {
			if (previousTooltipPoint != item.dataIndex) {

				previousTooltipPoint = item.dataIndex;

				$("#plottooltip").remove();
				var x = item.datapoint[0].toFixed(2),
				y = item.datapoint[1].toFixed(2);
				showPlotTooltip(item.pageX, item.pageY,
				    item.series.label + " of " + x + " = " + y);
				// thisplot.highlight(item.series, item.datapoint);
			}
		} else {
			$("#plottooltip").remove();
			// thisplot.unhighlight();
			previousTooltipPoint = null;            
		}
	});
	
	// setup settings to add and remove labels
	settingscontainer = $(".snupyplotsettings", container.parent());
	if (typeof settingscontainer !== 'undefined'){
		init_snupyplotsettings(container, settingscontainer);
	}
	
	
	return(plot);
}
