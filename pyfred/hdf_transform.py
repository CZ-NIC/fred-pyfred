import neo_cgi
from neo_util import HDF

def hdf_to_pyobj(hdf):
    def process_node(node):
        dict_part = {}
        list_part = []

        while node and node.name().isdigit():
            if node.value():
                list_part.append(node.value())
            else:
                list_part.append(process_node(node.child()))
            node = node.next()
        if list_part:
            return list_part

        while node:
            if node.value() is not None and not node.child():
                dict_part[node.name()] = node.value()
            else:
                dict_part[node.name()] = process_node(node.child())
            node = node.next()
        return dict_part

    return process_node(hdf.child())


def pyobj_to_hdf(pyobj, hdf=None):

    def make_key(lst):
        return '.'.join([str(i) for i in lst])

    def process_value(value, current_key, hdf):

        if isinstance(value, list):
            for idx, item in enumerate(value):
                process_value(item, current_key + [idx], hdf)
        elif isinstance(value, dict):
            for key, item in value.iteritems():
                process_value(item, current_key + [key], hdf)
        elif isinstance(value, str):
            hdf.setValue(make_key(current_key), value)
        else:
            hdf.setValue(make_key(current_key), str(value))

    if not hdf:
        hdf = HDF()
    process_value(pyobj, [], hdf)
    return hdf
