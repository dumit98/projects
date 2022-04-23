#!/usr/bin/env python3

from setuptools import setup
from setuptools import find_packages


with open('requirements.txt') as f:
    req = f.read().splitlines()

setup(
    name='cetdm',
    version='1.0.0',
    description='tools and modules for cetdm',
    url='https://stash.nov.com:8443/projects/CDM/repos/cetdm_python/browse/cetdm',
    packages=find_packages(),
    install_requires=req
)
