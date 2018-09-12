%global __os_install_post %(echo '%{__os_install_post}' | sed -e 's!/usr/lib[^[:space:]]*/brp-python-bytecompile[[:space:]].*$!!g')
Name:           %{project_name}
Version:        %{our_version}
Release:        %{?our_release}%{!?our_release:1}%{?dist}
Summary:        FRED - Python libraries
Group:          Applications/Utils
License:        GPL
URL:            http://fred.nic.cz
Source0:        %{name}-%{version}.tar.gz
Source1:        distutils-%{distutils_branch}.tar.gz
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-%(%{__id_u} -n)
BuildRequires: python
Requires: python python-omniORB omniORB-servers fred-idl python-clearsilver PyGreSQL < 5.0 python-dns ldns postfix m2crypto
%if 0%{?fedora}
Requires: ldns-utils
%endif

%description
FRED (Free Registry for Enum and Domain) is free registry system for 
managing domain registrations. This package contains python server component

%prep
%setup -b 1

%install
PYTHONPATH=%{_topdir}/BUILD/distutils-%{distutils_branch}:$PYTHONPATH python setup.py install -cO2 --force --root=$RPM_BUILD_ROOT --record=INSTALLED_FILES --prefix=/usr --install-sysconf=/etc --install-localstate=/var --no-check-deps --drill=/usr/bin/drill --sendmail=/usr/sbin/sendmail

%clean
rm -rf $RPM_BUILD_ROOT

%files -f INSTALLED_FILES
%defattr(-,root,root)
