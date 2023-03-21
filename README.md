# stp-kigam.pl
`stp-kigam.pl` is a version modified from [stp-iris.pl](https://github.com/lowbontimp/stp-iris) for the Big Data Open Platform of Korea Institute of Geoscience and Mineral Resources.

## Installation
### 1. Perl library

```
PERL_MM_USE_DEFAULT=1 perl -MCPAN -e 'install +LWP::UserAgent'
PERL_MM_USE_DEFAULT=1 perl -MCPAN -e 'install +Date::Calc::XS'
PERL_MM_USE_DEFAULT=1 perl -MCPAN -e 'install +LWP::Protocol::https'
```

## How to make a key (token)
### 1. Join the Big Data Open Platform at
```
[https://data.kigam.re.kr/auth/join?lang=en](https://data.kigam.re.kr/auth/join?lang=en)
```
Some of terms for joininig it is written in Korean (21 March 2023).

### 2. Request an authorization key (token) at
```
[https://data.kigam.re.kr/my-openapi/request/](https://data.kigam.re.kr/my-openapi/request/)
```
You might need a static IP address.

## Set your Authorization key
```
mkdir -p ~/.stp-kigam
echo your_token > ~/.stp-kigam/token
chmod 600 ~/.stp-kigam/token
```

## Usage
See the page of [stp-iris.pl](https://github.com/lowbontimp/stp-iris)

## Self-controlling rate of connection
[Guidelines for IRIS DMC services](http://ds.iris.edu/ds/nodes/dmc/services/usage/)
are requiring no more than *5 concurrent connections* and no more than *10 connections per second*.
Avoid running too many processes of `stp-iris.pl` simultaneously.
`stp-iris.pl` sleeps for a while when the averaged number of connections exceeds a threshold.
Removing or changing this part in `stp-iris.pl` needs carefulness.

