"""
This module gathers various utility functions used in other pyfred's modules.
"""
import hashlib


def countKeyTag(flags, protocol, alg, key):
    """
    Count keytag from RRDATA od DNSKEY RR according to appendix B of RFC 4034
    """
    if alg == 1:
        if (len(key) < 4):
            return 0;
        else:
            return (ord(key[len(key) - 4]) << 8) + ord(key[len(key) - 3])
    else :
        sum = flags + (protocol << 8) + alg
        for i in range(0, len(key)):
            if (i & 1):
                sum += ord(key[i])
            else:
                sum += ord(key[i]) << 8
        sum += (sum >> 16) & 0xFFFF
        return sum & 0xFFFF



dsrecord_algorithms = {
    "sha1": {"func": hashlib.sha1, "type": 1},
    "sha256": {"func": hashlib.sha256, "type": 2}
}


def count_dsrecord_digest(fqdn, flags, protocol, alg, key, digest_algo):
    """
    Count digest from fqdn and RRDATA of DNSKEY RR according to RFC 4034 (4509)
    using specified algorithm

    Returns tuple of digest type and digest
    """
    algo = dsrecord_algorithms[digest_algo]

    hash = algo["func"]()
    labels = fqdn.split(".")
    buffer = ""
    for l in labels:
        buffer += chr(len(l)) + l
    buffer += chr(0) + chr(flags >> 8) + chr(flags & 255) + chr(protocol)
    buffer += chr(alg) + key
    hash.update(buffer)
    return (algo["type"], hash.hexdigest().upper())
