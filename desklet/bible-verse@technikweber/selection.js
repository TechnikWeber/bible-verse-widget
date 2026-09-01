/*
 * Verse selection — shared verbatim by the Plasmoid and the Desklet.
 *
 * See shared/selection.md for the specification and tests/test_selection.py for
 * the reference implementation this file is verified against.
 *
 * Written in plain ES5 with top-level function declarations so that the same
 * file loads both as a QML JavaScript resource and as a GJS module
 * (`imports.selection`). Do not add `let`, `const`, classes or modules here.
 */

var SELECTION_MODULUS = 2147483647;
var SELECTION_MULTIPLIER = 48271;
var SELECTION_YEAR_SALT = 2654435761;

/* Lehmer / MINSTD. All products stay below 2^53, so this is exact in doubles
 * and gives identical results in Python, QML and GJS. */
function makeRandom(seed) {
    var state = seed % SELECTION_MODULUS;
    if (state <= 0) {
        state += SELECTION_MODULUS - 1;
    }
    return function () {
        state = (state * SELECTION_MULTIPLIER) % SELECTION_MODULUS;
        return state;
    };
}

/* Deterministic shuffle of [0 … count-1], reseeded every calendar year. */
function yearPermutation(year, count) {
    var next = makeRandom((year * SELECTION_YEAR_SALT) % SELECTION_MODULUS);
    var perm = new Array(count);
    var i, j, tmp;
    for (i = 0; i < count; i++) {
        perm[i] = i;
    }
    for (i = count - 1; i > 0; i--) {
        j = next() % (i + 1);
        tmp = perm[i];
        perm[i] = perm[j];
        perm[j] = tmp;
    }
    return perm;
}

function dayOfYear(date) {
    var start = new Date(date.getFullYear(), 0, 1);
    var today = new Date(date.getFullYear(), date.getMonth(), date.getDate());
    return Math.round((today - start) / 86400000) + 1;
}

/* Index into the verse list for the given local date. */
function verseIndexForDate(date, count) {
    if (count <= 0) {
        return 0;
    }
    var perm = yearPermutation(date.getFullYear(), count);
    return perm[(dayOfYear(date) - 1) % count];
}
