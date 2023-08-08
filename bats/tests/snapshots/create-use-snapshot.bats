load '../helpers/load'

# Hey Jan: why does this keep changing?
SNAPSHOT="$(basename "$(mktemp -u -t moby.XXXXX)")"
SNAPSHOT=moby-nginx-snapshot01

local_setup() {
    if is_windows; then
        skip "snapshots test not applicable on Windows"
    fi
}

@test 'factory reset and delete the snapshot if it exists' {
    factory_reset
    run get_snapshot_id_from_name "$SNAPSHOT"
    assert_success
    echo "output is [$output]" 1>&3
    if [[ -n $output ]]; then
        echo "Go delete snapshot <$output>" 1>&3
        rdctl snapshot delete "$output"
    else
        echo "No snapshot found to delete" 1>&3
    fi
}

@test 'start up in moby' {
    RD_CONTAINER_ENGINE=moby
    start_kubernetes
    wait_for_container_engine
    wait_for_apiserver
}

start_nginx() {
    run kubectl get pods
    assert_success
    assert_output --regexp 'nginx.*Running'
}

running_nginx() {
    run kubectl get pods -A
    assert_success
    assert_output --regexp 'default.*nginx.*Running'
}

@test 'push an nginx pod and verify' {
    kubectl run nginx --image=nginx:latest --port=8080
    try --max 48 --delay 5 running_nginx
    # TODO: hit the nginx container with curl
}

@test 'shutdown, make a snapshot, and clear everything' {
    rdctl shutdown
    rdctl snapshot create "$SNAPSHOT"
    run rdctl snapshot list
    assert_success
    assert_output --partial "$SNAPSHOT"
    rdctl factory-reset
}

@test 'startup, verify using new defaults' {
    RD_CONTAINER_ENGINE=containerd
    start_kubernetes
    wait_for_container_engine
    wait_for_apiserver
    run rdctl api /settings
    assert_success
    run jq_output .containerEngine.name
    assert_success
    assert_output --partial containerd
    run kubectl get pods -A
    assert_success
    refute_output --regexp 'default.*nginx.*Running'
}

# This should be one long test because if `snapshot restore` fails there's no point starting up
@test 'shutdown, restore, restart and verify snapshot state' {
    local snapshotID
    rdctl shutdown
    run get_snapshot_id_from_name "$SNAPSHOT"
    assert_success
    refute_output ""
    snapshotID="$output"
    run rdctl snapshot restore "$snapshotID"
    assert_success
    refute_output --partial $"failed to restore snapshot \"$snapshotID\""

    # Circumvent having start_kubernetes => start_container_engine set all the defaults
    # by running `yarn dev` or `rdctl start` directly here.
    if using_dev_mode; then
        # translate args back into the internal API format
        yarn dev --no-modal-dialogs
    else
        RD_TEST=bats rdctl start --no-modal-dialogs &
    fi

    # Keep this variable in sync with
    RD_CONTAINER_ENGINE=moby
    wait_for_container_engine
    wait_for_apiserver
    run rdctl api /settings
    assert_success
    run jq_output
    assert_success
    assert_output --partial moby
    kubectl get pods -A
    assert_output --regexp 'default.*nginx.*Running'
}
