/** VISTRA V2: Chart.js presentation only. Never changes labels or numeric data. */
(() => {
  'use strict';
  if (typeof Chart === 'undefined') return;
  const motion = window.matchMedia('(prefers-reduced-motion: reduce)');
  const tokens = getComputedStyle(document.documentElement);
  const color = name => tokens.getPropertyValue(name).trim();
  const text = color('--v-muted');
  const ink = color('--v-text');
  const cyan = color('--v-cyan');
  const line = color('--v-line');
  const replaceColor = value => {
    if (Array.isArray(value)) return value.map(replaceColor);
    if (typeof value !== 'string') return value;
    const mapped = {
      '#6547e8': '#22d3ee', '#6354d9': '#2563eb', '#8b5cf6': '#38bdf8',
      '#4d40b8': '#1d4ed8', '#7c3aed': '#22d3ee', '#7c5ce6': '#22d3ee', '#8065f5': '#38bdf8', '#a99bf4': '#7dd3fc',
      '#c9c3f3': '#4b9bd6', '#b9b2cc': '#6c89ac', '#ffffff': '#132341', '#eeeaf8': '#203551',
      '#f3f4f6': '#203551', 'rgba(101,71,232,0.14)': 'rgba(34,211,238,0.14)'
    };
    const compact = value.toLowerCase().replace(/\s+/g, '');
    if (mapped[compact]) return mapped[compact];
    // Legacy translucent purple fills keep their alpha, with the cyan hue.
    const rgba = compact.match(/^rgba?\((\d+),(\d+),(\d+)(?:,([\d.]+))?\)$/);
    if (rgba) {
      const [, r, g, b, alpha = '1'] = rgba;
      if (+b > +r && +r > +g * 1.1 && +b > +g * 1.4) return `rgba(34,211,238,${alpha})`;
    }
    return value;
  };
  Chart.register({
    id: 'vistraMidnight',
    beforeUpdate(chart) {
      const options = chart.config.options;
      if (motion.matches) options.animation = false;
      else if (options.animation !== false) {
        options.animation = { ...(typeof options.animation === 'object' ? options.animation : {}), duration: 650, easing: 'easeOutQuart', delay: 0 };
      }
      Object.values(options.scales || {}).forEach(scale => {
        scale.ticks = { ...scale.ticks, color: text, backdropColor: 'transparent' };
        scale.grid = { ...scale.grid, color: line };
        scale.border = { ...scale.border, color: line };
        if (scale.title) scale.title.color = text;
        if (scale.pointLabels) scale.pointLabels.color = ink;
        if (scale.angleLines) scale.angleLines.color = line;
      });
      options.plugins = options.plugins || {};
      if (options.plugins.legend !== false) {
        options.plugins.legend = options.plugins.legend || {};
        options.plugins.legend.labels = { ...options.plugins.legend.labels, color: text, usePointStyle: true, boxWidth: 8 };
      }
      if (options.plugins.tooltip !== false) {
        options.plugins.tooltip = { ...options.plugins.tooltip, backgroundColor: '#101e37', titleColor: ink, bodyColor: ink, borderColor: line, borderWidth: 1, cornerRadius: 10, padding: 12 };
      }
      chart.data.datasets.forEach(dataset => {
        ['backgroundColor', 'borderColor', 'hoverBackgroundColor', 'hoverBorderColor', 'pointBackgroundColor', 'pointBorderColor', 'pointHoverBackgroundColor', 'pointHoverBorderColor'].forEach(key => {
          if (dataset[key] !== undefined) dataset[key] = replaceColor(dataset[key]);
        });
      });
    }
  });
  Chart.defaults.color = text;
  Chart.defaults.borderColor = line;
  Chart.defaults.font.family = '"Plus Jakarta Sans", system-ui, sans-serif';
  Chart.defaults.elements.point.hoverBackgroundColor = cyan;
  const refresh = () => Object.values(Chart.instances).filter(chart => chart.canvas && chart.ctx).forEach(chart => chart.update('none'));
  motion.addEventListener('change', refresh);
  refresh();
})();
