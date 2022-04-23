#!/usr/bin/env python3

from setuptools import setup


setup(
    name='tetl-cli',
    version='1.0.0',
    description='command line interface wrapper for the tiny_etl module',
    author='Antonio Dumit',
    author_email='Antonio.Dumit@nov.com',
    packages=['tetl'],
    entry_points={
        'console_scripts': [
            'tetl = tetl.tetl:main'
        ],
    },
)
