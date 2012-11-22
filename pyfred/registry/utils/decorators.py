#!/usr/bin/python
from pyfred.registry.utils.cursors import DatabaseCursor
from pyfred.registry.utils import normalize_and_check_handle, normalize_and_check_domain


def furnish_database_cursor_m(interface_function):
    """
    Decorator furnishes the interface object by the open database cursor.
    Closes cursor and db connections even if the exception occurs.
    """

    def wrapper(self, *args, **kwargs):
        "Decorate an interface class method."
        #self.logger.log(self.logger.DEBUG, '@furnish_database_cursor_m BEGIN') # DEBUG ONLY
        with DatabaseCursor(self.database, self.logger, self.INTERNAL_SERVER_ERROR) as cursor:
            self.cursor = cursor
            retval = interface_function(self, *args, **kwargs)
            self.cursor = None
        #self.logger.log(self.logger.DEBUG, '@furnish_database_cursor_m END') # DEBUG ONLY
        return retval

    return wrapper


def _normalize_attrs(logger, transform_type, list_of_attrs, *args, **kwargs):
    """
    Normalize attributes. Used in devorators.
    """
    boundary = len(args)
    attrs = list(args)

    normalize = normalize_and_check_domain if transform_type == "domain" else normalize_and_check_handle

    for position, key in list_of_attrs:
        if position < boundary:
            attrs[position] = normalize(logger, attrs[position])
        elif key in kwargs:
            kwargs[key] = normalize(logger, kwargs[key])

    args = tuple(attrs)

    return tuple(attrs), kwargs


def normalize_contact_handle_m(interface_function):
    """
    Normalize contact handle and check the validity.
    Raise Registry.DomainBrowser.INCORRECT_USAGE in case of invalid format.
    """
    def wrapper(self, *args, **kwargs):
        "Decorate an interface class method."
        args, kwargs = _normalize_attrs(self.logger, "handle", ((0, "handle"),), *args, **kwargs)
        return interface_function(self, *args, **kwargs)

    return wrapper


def normalize_handles_m(list_of_attrs):
    """
    list_of_attrs are positions and names of function attributes:
    ((position, key), ...) --> fnc(value) / fnc(key=value)
    """
    def decorator(interface_function):
        """
        Normalize handle and check the validity.
        Invalid handle raise Registry.DomainBrowser.INCORRECT_USAGE.
        """
        def wrapper(self, *args, **kwargs):
            "Decorate an interface class method."
            args, kwargs = _normalize_attrs(self.logger, "handle", list_of_attrs, *args, **kwargs)
            return interface_function(self, *args, **kwargs)

        return wrapper
    return decorator


def normalize_domain_m(interface_function):
    """
    Parameter domain must be at the second position and have name 'domain'.
    """
    def wrapper(self, *args, **kwargs):
        "Decorate an interface class method."
        args, kwargs = _normalize_attrs(self.logger, "domain", ((1, "domain"),), *args, **kwargs)
        return interface_function(self, *args, **kwargs)

    return wrapper
