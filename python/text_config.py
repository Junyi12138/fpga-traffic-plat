# test_config.py
# Of the 27 combinations, the 9 traffic patterns (3 densities x 3 road
# types) are defined here. The control-model dimension is switched
# manually and isn't handled here.

BASE_INTERVAL = {
    'light':  5.0,   # seconds per vehicle duration
    'medium': 2.5,
    'heavy':  1.0,
}

MINOR_MULTIPLIER = 2   # minor road's multiplier relative to the major road

def build_test_matrix():
    """(density, road_type) -> ac_interval / bd_interval
    AC is always the major road, BD is always the minor road (only this
    asymmetric pairing is tested, not the reverse)."""
    matrix = []
    for density, base in BASE_INTERVAL.items():
        for road_type in ['major-major', 'major-minor', 'minor-minor']:
            if road_type == 'major-major':
                ac_mult, bd_mult = 1, 1
            elif road_type == 'minor-minor':
                ac_mult, bd_mult = MINOR_MULTIPLIER, MINOR_MULTIPLIER
            else:  # major-minor
                ac_mult, bd_mult = 1, MINOR_MULTIPLIER

            matrix.append({
                'density': density,
                'road_type': road_type,
                'ac_interval': base * ac_mult,
                'bd_interval': base * bd_mult,
            })
    return matrix

TEST_MATRIX = build_test_matrix()
