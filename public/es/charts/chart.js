import chartApp from './chart_app';
import { filter, map, each } from 'underscore';
import * as nv from 'nvd3';

/**
 * create the NVD3 chart with the given options
 */
var createChart = function($svgElt, options) {
  var chart;
  switch(options.chartType) {
    case 'multiBarChart' :
      chart = nv.models.multiBarChart();
      break;
    case 'lineChart' :
      chart = nv.models.lineChart();
      break;
    case 'donutChart' :
      chart = nv.models.pieChart().donut(true);
      break;
    default:
      chart = nv.models.stackedAreaChart();
      break;
  }

  // chart options
  chart.options(options);

  // x axis options
  var xAxis = chart.xAxis;
  if(xAxis) {
    options.xAxisTickPadding && xAxis.tickPadding(options.xAxisTickPadding);
    options.xAxisFormat && xAxis.tickFormat(options.xAxisFormat);
    options.xAxisTimeScale && chart.xScale && chart.xScale(d3.time.scale());
    xAxis.showMaxMin(false);

    if(options.customDiscreteDateValuesFix) {
      // HACK: For line and area charts, D3 time scale will automatically set
      // spaced ticks. However, ticks are not guaranteed to be one of the
      // values (e.g. a monthly chart can have a tick for the 17th of
      // a month). We want to force discrete ticks so we have to manually set
      // the tick values. Because we don't want the ticks to overlap, we
      // filter the ticks. The filtering rules comes from NVD3's reduceXTicks
      // directive used for multiBarCharts. See
      // https://github.com/novus/nvd3/blob/05cfaafa872ec8f941f7349bcf83fc7d344db857/src/models/multiBarChart.js#L262
      xAxis.tickValues(function(data){
        var margin = options.margin.left + options.margin.right;
        var availableWidth = $svgElt.width() - margin;
        var allValues = data[0].values;
        var values = filter(allValues,  function(v, i) {
          return i % Math.ceil(allValues.length / availableWidth * 100) === 0;
        });
        return map(values, function(v) {
          return new Date(v.x);
        });
      });
    }
  }

  // y axis options
  var yAxis = chart.yAxis;
  if(yAxis) {
    options.yAxisTickPadding && yAxis.tickPadding(options.yAxisTickPadding);
    options.yAxisFormat && yAxis.tickFormat(options.yAxisFormat);
  }

  if(options.customTooltipValue) {
    var contentGenerator = chart.interactiveLayer.tooltip.contentGenerator();
    chart.interactiveLayer.tooltip.contentGenerator(function(data) {
      var generatedTooltipHtml = contentGenerator(data);
      var $html = $('<div />', { html: generatedTooltipHtml });

      each(data.series, function(serie, idx){
        var customValue =  options.customTooltipValue(serie);
        $html.find('.value').eq(idx).text(customValue);
      });

      return $html.html();
    });
  }

  // fix header formatting so the date always use the yAxis format
  if(chart.interactiveLayer) {
    chart.interactiveLayer.tooltip.headerFormatter(function (data) {
      console.log("Options 2", options)
      return options.xAxisFormat(data);
    });
  }

  chart.noData('No data available for the selected dates');

  chartApp.charts.push(chart);
  return chart;
};

/**
 * Add custom colours to each dataset in a graph. Colours are shades of blue
 * for the first 5 datasets, then shades of grey. Useful when all dataset for
 * a graph are related.
 */
var formatShadedColor = function(data) {
  var choosenColour, colourR, colourG, colourB;

  // loop over all datasets
  each(data, function(lineData, i) {
    if(i < 5 ) {
      // first 5 colours are shades of blue (from dark to light)
      colourR = 71 + (255 - 71) / 5 * i;
      colourG = 107 + (255 - 107) / 5 * i;
      colourB = 190 + (255 - 190) / 5 * i;
    } else {
      // remaining colours are shades of grey (from light to dark)
      colourR = colourG = colourB = 255 - 255 / data.length * i;
    }
    lineData.color = "#" +
      parseInt(colourR).toString(16) +
      parseInt(colourG).toString(16) +
      parseInt(colourB).toString(16);
  });
  return data;
};

export { createChart };
