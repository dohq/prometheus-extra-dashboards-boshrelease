# prometheus-extra-dashboards-boshrelease
this boshrelease is useful addon for [prometheus-boshrelease](https://github.com/cloudfoundry-community/prometheus-boshrelease)


## Usage
add prometheus-extra-dashboards-boshrelease/ops-files to prometheus-boshrelease.  
```
bosh -d prometheus deploy prometheus-boshrelease/manifests/prometheus.yml \
-o prometheus-extra-dashboards-boshrelease/manifests/prometheus-extra-dashboards.yml \
-o prometheus-extra-dashboards-boshrelease/manifests/ops-files/monitor-micrometer.yml \
-o prometheus-extra-dashboards-boshrelease/manifests/ops-files/monitor-hystrix.yml \
--no-redact

```

## Requirements
[prometheus-boshrelease](https://github.com/cloudfoundry-community/prometheus-boshrelease)

## Author
[dohq](https://github.com/dohq)

## License
Apache 2.0 License

## Special Thanks
[making](https://github.com/making) donate an micrometer dashboards.
