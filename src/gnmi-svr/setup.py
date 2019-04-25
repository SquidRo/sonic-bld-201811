from setuptools import setup, find_packages

dependencies = [
    'pyangbind',
]

setup(
    name='gnmi-svr',
    install_requires=dependencies,
    version='0.1',
    packages=find_packages(),
    license='Apache 2.0',
    author='',
    author_email='',
    entry_points={
        'console_scripts': [
            'gnmi_server = my_gnmi_server.gnmi_server:main'
        ]
    },
    maintainer='',
    maintainer_email='',
    classifiers=[
        'Intended Audience :: Developers',
        'Operating System :: Linux',
        'Programming Language :: Python',
    ],

)
