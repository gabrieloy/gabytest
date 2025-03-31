const chartJsUrl = 'https://cdn.jsdelivr.net/npm/chart.js';

function drawRadarChart(data, element) {
  const labels = data.fields.dimensions.map(d => d.name);
  const values = data.rows.map(row => row.metrics.map(m => m.value));

  const datasets = values.map((metricSet, i) => ({
    label: `Row ${i + 1}`,
    data: metricSet,
    fill: true
  }));

  const canvas = document.createElement("canvas");
  element.innerHTML = "";
  element.appendChild(canvas);

  new Chart(canvas.getContext("2d"), {
    type: 'radar',
    data: {
      labels: labels,
      datasets: datasets
    },
    options: {
      responsive: true,
      plugins: {
        legend: { position: 'top' },
        title: { display: true, text: 'Custom Radar Chart' }
      }
    }
  });
}

function init() {
  const script = document.createElement('script');
  script.src = chartJsUrl;
  script.onload = () => {
    looker.plugins.visualizations.add({
      id: 'radar_chart',
      label: 'Radar Chart',
      create: function (element, config) {
        this.element = element;
      },
      updateAsync: function (data, element, config, queryResponse, details, done) {
        drawRadarChart(data, this.element);
        done();
      }
    });
  };
  document.head.appendChild(script);
}

init();
