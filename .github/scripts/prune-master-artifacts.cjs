// Called only after both image jobs succeed on a push to master.
module.exports = async ({ github, context, core }) => {
  if (context.eventName !== 'push' || context.ref !== 'refs/heads/master') {
    throw new Error('Artifact cleanup requires a master push');
  }

  const actions = github.rest.actions;
  const { data: current } = await actions.getWorkflowRun({
    ...context.repo, run_id: context.runId,
  });
  const runs = await github.paginate(actions.listWorkflowRuns, {
    ...context.repo, workflow_id: current.workflow_id,
    branch: 'master', event: 'push', per_page: 100,
  }, response => response.data.workflow_runs);

  // An older rerun must not remove the outputs of a newer successful build.
  // The current run is still in progress, but needs: [build, pxe] passed.
  const successful = [current, ...runs.filter(run => run.conclusion === 'success')];
  const latest = successful.reduce((a, b) => a.run_number > b.run_number ? a : b);
  const older = new Set(runs.filter(run => run.run_number < latest.run_number).map(run => run.id));
  const artifacts = await github.paginate(actions.listArtifactsForRepo, {
    ...context.repo, per_page: 100,
  }, response => response.data.artifacts);
  const names = new Set(['fdi-bootc-oci-master', 'fdi-pxe-master']);

  for (const artifact of artifacts) {
    if (!names.has(artifact.name) || !older.has(artifact.workflow_run?.id)) continue;

    core.info(`Deleting ${artifact.name} from older master run ${artifact.workflow_run.id}`);
    await actions.deleteArtifact({ ...context.repo, artifact_id: artifact.id });
  }
  core.info(`Keeping image artifacts from master run ${latest.run_number}`);
};
