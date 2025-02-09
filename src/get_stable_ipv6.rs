use neli::consts::nl::{NlmF, NlmFFlags, Nlmsg};
use neli::consts::rtnl::{Ifa, IfaFFlags, RtAddrFamily, Rtm};
use neli::consts::socket::NlFamily;
use neli::nl::{NlPayload, Nlmsghdr};
use neli::rtnl::Ifaddrmsg;
use neli::socket::NlSocketHandle;
use neli::types::RtBuffer;
use neli::ToBytes; // For converting flags to bytes
use std::convert::TryInto;
use std::io::Cursor;
use std::net::Ipv6Addr;

// In many Linux systems, secondary (privacy) addresses get flag 0x01
const IFA_F_SECONDARY: u8 = 0x01;
const IFA_F_TEMPORARY: u8 = 0x02;

/// Returns a candidate stable global IPv6 address, if one is found.
pub fn get_stable_ipv6() -> Option<Ipv6Addr> {
    // Connect to NETLINK_ROUTE.
    let mut socket =
        NlSocketHandle::connect(NlFamily::Route, None, &[]).expect("Failed to open netlink socket");

    // Build an Ifaddrmsg request.
    let ifaddr_msg = Ifaddrmsg {
        ifa_family: RtAddrFamily::Inet6,         // Request IPv6 addresses.
        ifa_prefixlen: 0,                        // No prefix filter at request time.
        ifa_flags: IfaFFlags::from_bitmask(0u8), // No flags in the request.
        ifa_scope: 0,
        ifa_index: 0,             // 0 means "all interfaces".
        rtattrs: RtBuffer::new(), // Empty attribute buffer.
    };

    // Combine netlink header flags.
    let flags_u16 = u16::from(NlmF::Request) | u16::from(NlmF::Dump);
    let nl_flags = NlmFFlags::from_bitmask(flags_u16);

    let req = Nlmsghdr::new(
        None,
        Rtm::Getaddr,
        nl_flags,
        None,
        None,
        NlPayload::Payload(ifaddr_msg),
    );

    socket.send(req).ok()?;

    let mut candidate: Option<Ipv6Addr> = None;

    // Loop over received netlink messages.
    while let Some(response) = socket.recv::<Rtm, Ifaddrmsg>().ok()? {
        if u16::from(response.nl_type) == u16::from(Nlmsg::Done) {
            break;
        }
        if u16::from(response.nl_type) != u16::from(Rtm::Newaddr) {
            continue;
        }
        let ifa_msg: Ifaddrmsg = match response.nl_payload {
            NlPayload::Payload(p) => p,
            _ => continue,
        };

        // Process only IPv6 addresses.
        if ifa_msg.ifa_family != RtAddrFamily::Inet6 {
            continue;
        }
        // Filter for addresses with a /64 prefix.
        if ifa_msg.ifa_prefixlen != 64 {
            continue;
        }
        // Filter out non-global addresses (link-local, etc.).
        if ifa_msg.ifa_scope != 0 {
            continue;
        }

        // Convert flags to a byte without unsafe code using the ToBytes trait.
        let mut cursor = Cursor::new(Vec::new());
        ifa_msg.ifa_flags.to_bytes(&mut cursor).ok()?;
        let flag_vec = cursor.into_inner();
        let flag_bits = flag_vec.into_iter().next()?;

        // Check that the secondary and temporary flag are not set (to avoid temporary addresses).
        if flag_bits & IFA_F_SECONDARY != 0 {
            continue;
        }

        if flag_bits & IFA_F_TEMPORARY != 0 {
            continue;
        }

        // Iterate over the attributes to find the raw address.
        for attr in ifa_msg.rtattrs.into_iter() {
            if attr.rta_type == Ifa::Address {
                if attr.rta_payload.as_ref().len() == 16 {
                    let addr: [u8; 16] = attr.rta_payload.as_ref().try_into().ok()?;
                    candidate = Some(Ipv6Addr::from(addr));
                    break;
                }
            }
        }
        if candidate.is_some() {
            break;
        }
    }

    candidate
}
