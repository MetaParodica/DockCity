import fs from 'node:fs';
import { pathToFileURL } from 'node:url';

export function summarize(records) {
  const trials = [];
  let trial;
  for (const row of records) {
    if (!Number.isFinite(row.elapsed_ms)) continue;
    if (row.event === 'pointer_edge_enter_sampled') {
      trial = { edge_ms: row.elapsed_ms, dock_ms: null, ax_ms: null, city_ms: null, order_front_ms: null, reads: 0, max_read_ms: 0 };
      trials.push(trial);
    }
    if (!trial) continue;
    const elapsed = row.elapsed_ms - trial.edge_ms;
    if (elapsed < 0) continue;
    if (row.event === 'ax_snapshot') {
      trial.reads++;
      if (Number.isFinite(row.read_ms)) trial.max_read_ms = Math.max(trial.max_read_ms, row.read_ms);
      if (row.dock_visible && trial.dock_ms === null) trial.dock_ms = elapsed;
      if (row.ax_visible && trial.ax_ms === null) trial.ax_ms = elapsed;
    }
    if (row.event === 'city_order_front' && trial.order_front_ms === null) trial.order_front_ms = elapsed;
    if (row.event === 'city_first_visible_geometry' && trial.city_ms === null) trial.city_ms = elapsed;
  }
  return { note: 'Observed sampled timings, not exact WindowServer animation start. Null means unobserved.', trials };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  if (!process.argv[2]) { console.error('Usage: node scripts/summarize-dock-trace.mjs path/to/trace.jsonl'); process.exit(64); }
  const rows = fs.readFileSync(process.argv[2], 'utf8').split(/\r?\n/).flatMap(line => {
    try { return [JSON.parse(line)]; } catch { return []; }
  });
  console.log(JSON.stringify(summarize(rows), null, 2));
}
