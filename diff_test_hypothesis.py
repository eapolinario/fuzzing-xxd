import subprocess
from pathlib import Path

from hypothesis import given, settings, strategies as st

from hypothesis import settings, Verbosity
# settings.default.verbosity = Verbosity.verbose

# Adjust these paths to your actual binaries:
XXD_REF = Path("/usr/bin/xxd")   # "ground truth" xxd for encoding
XXD_A = Path("/home/eduardo/repos/eapolinario-ggd/build/ggd")   # path to implementation A
# TODO: Point XXD_B to zzd once https://github.com/eapolinario/zzd/issues/3 is fixed
XXD_B = XXD_REF


def run_cmd(argv, stdin: bytes):
    """Run a command with stdin bytes, return (rc, stdout, stderr)."""
    proc = subprocess.run(
        list(map(str, argv)),
        input=stdin,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    return proc.returncode, proc.stdout, proc.stderr


def xxd_encode_ref(data: bytes) -> bytes:
    """Encode binary -> hexdump using a reference xxd."""
    rc, out, err = run_cmd([XXD_REF], data)
    if rc != 0:
        raise RuntimeError(f"ref xxd failed: rc={rc}, stderr={err!r}")
    return out


def xxd_reverse(binary: Path, hexdump: bytes):
    """Run `binary -r` on the given hexdump, returning (rc, stdout, stderr)."""
    return run_cmd([binary, "-r"], hexdump)


# Strategy: arbitrary binary blobs up to, say, 4 KiB
binary_blobs = st.binary(min_size=0, max_size=4096)


@settings(
    max_examples=10_000_000,
    verbosity=Verbosity.verbose,
)  # tune as you like
@given(data=binary_blobs)
def test_xxd_reverse_implementations_agree_on_roundtrip(data: bytes):
    # 1) encode with reference xxd
    hexdump = xxd_encode_ref(data)

    # 2) decode with both implementations
    rc_a, out_a, err_a = xxd_reverse(XXD_A, hexdump)
    rc_b, out_b, err_b = xxd_reverse(XXD_B, hexdump)

    # 3) basic expectations: both should succeed
    assert rc_a == 0, f"xxdA failed with rc={rc_a}, stderr={err_a!r}"
    assert rc_b == 0, f"xxdB failed with rc={rc_b}, stderr={err_b!r}"

    # 4) both should reproduce the original data
    assert out_a == data, "xxdA -r did not reproduce original bytes"
    assert out_b == data, "xxdB -r did not reproduce original bytes"

    # 5) and they should agree with each other
    assert out_a == out_b, "xxdA -r and xxdB -r disagree on output"
