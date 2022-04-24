#!/usr/bin/env python3

from setuptools import setup
from setuptools import find_packages


with open('requirements.txt') as f:
    req = f.read().splitlines()

setup(
    name='my_modules',
    version='1.0.0',
    description='some tools and modules',
    url='https://github.com/dumit98/projects/tree/master/modules',
    packages=find_packages(),
    install_requires=req
)
