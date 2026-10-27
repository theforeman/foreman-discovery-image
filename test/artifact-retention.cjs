const assert = require('node:assert/strict');
const test = require('node:test');
const prune = require('../.github/scripts/prune-master-artifacts.cjs');

function run(id, conclusion = 'success') {
  return { id, run_number: id, workflow_id: 42, conclusion };
}

function artifact(id, name, runId) {
  return { id, name, workflow_run: { id: runId } };
}

async function simulate(current, runs, artifacts, eventName = 'push') {
  const deleted = [];
  const actions = {
    getWorkflowRun: async () => ({ data: current }),
    listWorkflowRuns: 'runs',
    listArtifactsForRepo: 'artifacts',
    deleteArtifact: async ({ artifact_id }) => deleted.push(artifact_id),
  };
  await prune({
    context: { repo: { owner: 'example', repo: 'fdi' }, runId: current.id, ref: 'refs/heads/master', eventName },
    core: { info: () => {} },
    github: {
      rest: { actions },
      paginate: async (endpoint, options, transform) => {
        if (endpoint === 'runs') {
          assert.equal(options.workflow_id, 42);
          assert.equal(options.branch, 'master');
          assert.equal(options.event, 'push');
          return transform({ data: { workflow_runs: runs } });
        }
        return transform({ data: { artifacts } });
      },
    },
  });
  return deleted;
}

test('successful replacement removes only older master images', async () => {
  const current = run(3, null);
  const artifacts = [
    artifact(1, 'fdi-pxe-master', 1),
    artifact(2, 'fdi-bootc-oci-master', 2), // Failed PXE build's OCI can also be removed.
    artifact(3, 'fdi-pxe-master', 3),
    artifact(4, 'fdi-bootc-oci-master', 3),
    artifact(5, 'fdi-pxe-pr-182', 1),
    artifact(6, 'fdi-pxe-logs-master', 1),
    artifact(7, 'fdi-pxe-master', 99), // A different workflow/PR is not in the run list.
    artifact(8, 'unrelated', 1),
  ];
  assert.deepEqual(await simulate(current, [run(1), run(2, 'failure'), current], artifacts), [1, 2]);
});

test('an older rerun preserves the newer successful build', async () => {
  const current = run(2, null);
  const artifacts = [artifact(1, 'fdi-pxe-master', 2), artifact(2, 'fdi-pxe-master', 3)];
  assert.deepEqual(await simulate(current, [current, run(3)], artifacts), [1]);
});

test('a newer failed or running build does not replace the last successful image', async () => {
  const current = run(2, null);
  const artifacts = [artifact(1, 'fdi-pxe-master', 1), artifact(2, 'fdi-pxe-master', 2), artifact(3, 'fdi-bootc-oci-master', 3)];
  assert.deepEqual(await simulate(current, [run(1), current, run(3, 'failure'), run(4, null)], artifacts), [1]);
});

test('PR execution refuses to delete anything', async () => {
  await assert.rejects(simulate(run(2), [run(1)], [], 'pull_request'), /requires a master push/);
});
