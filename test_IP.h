typedef nx_struct ipv6_hdr{
    nx_uint32_t V_TC_FL; /* 4 bits version, 8 bits class label 20 bits flow label at the end */
    nx_uint16_t payload_len;
    nx_uint8_t next_header;
    nx_uint8_t hop_limit;
    nx_uint8_t src_addr[16];
    nx_uint8_t dst_addr[16];
} ipv6_hdr_t;

