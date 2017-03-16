FROM debian

COPY run_tail /
COPY run_date /
COPY healthcheck /

CMD ["/run_date"]
