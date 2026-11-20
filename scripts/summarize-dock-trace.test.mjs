import test from 'node:test';
import assert from 'node:assert/strict';
import { summarize } from './summarize-dock-trace.mjs';

test('correlates sampled edge, Dock, AX and city observations', () => {
  const result = summarize([
    { event: 'pointer_edge_enter_sampled', elapsed_ms: 100 },
    { event: 'ax_snapshot', elapsed_ms: 150, read_ms: 21, dock_visible: true, ax_visible: false },
    { event: 'ax_snapshot', elapsed_ms: 230, read_ms: 42, dock_visible: true, ax_visible: true },
    { event: 'city_order_front', elapsed_ms: 245 },
    { event: 'city_first_visible_geometry', elapsed_ms: 250 },
  ]).trials[0];
  assert.deepEqual(result, { edge_ms: 100, dock_ms: 50, ax_ms: 130, city_ms: 150, order_front_ms: 145, reads: 2, max_read_ms: 42 });
});
test('does not invent missing timings and resets correlation for each trial', () => {
  const result = summarize([
    { event: 'city_order_front', elapsed_ms: 1 },
    { event: 'pointer_edge_enter_sampled', elapsed_ms: 10 },
    { event: 'ax_snapshot', elapsed_ms: 12, read_ms: 1, dock_visible: false, ax_visible: false },
    { event: 'pointer_edge_enter_sampled', elapsed_ms: 40 },
    { event: 'city_order_front', elapsed_ms: 50 },
    { event: 'city_first_visible_geometry', elapsed_ms: 51 },
    { event: 'ax_snapshot', elapsed_ms: NaN },
  ]).trials;
  assert.equal(result[0].city_ms, null); assert.equal(result[0].dock_ms, null);
  assert.equal(result[1].city_ms, 11); assert.equal(result[1].reads, 0);
});
