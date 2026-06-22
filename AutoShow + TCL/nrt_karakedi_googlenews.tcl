###########################################################################################
##                     ____  ____  _     ____  _     ____ 	                         ##
##                     /  _ \/ ___\/ \   /  __\/ \   / ___\	                         ##
##                    | / \||    \| |   |  \/|| |   |    \	                         ##
##                     | |-||\___ || |_/\|  __/| |_/\\___ |	                         ##
##                    \_/ \|\____/\____/\_/   \____/\____/	                         ##
##                      asl_pls / irc.underx.org #aslpls    	                         ##
##                                                                               06/2026 ##
########################################################################################### 
#											
# Google news v0.3 by nrt (01 Dec 2015)					
#
# 04 Jan 2018 Updated GoogleNews Country links and added some more lines for redirected link support by karakedi
#											
# ORIGINALLY BY: nrt & karakedi (Thank you, guys)					
#										
# 06/2026
#
# Google news v0.6 (Updated 2026 - Philippines Support & Bug Fixes)
#										
# Commands: .chanset #channel +googlenews					
#										
# In the channel: .news on (enable the news in the channel) / .news (to show rss feed news in the channel)	
#										
###########################################################################################

package require tdom
package require http
package require htmlparse
package require textutil::split
package require tls
package present Tcl 8.6

set ::oldnews [list]

# Modern base Google RSS feed URL path
set googlelink {https://news.google.com/rss/headlines/section/topic/NATION}

# Length of chars in a line.
set newsmax 412

# Links shortened to tinyurl. 1 = true , 0 = false
set tinyurl 1

# Language selection index - Set to 37 for Philippines (English)
set newslang 37

# Time threshold: Do not post automatically if headline is older than X minutes
set headlinedelay 20

# Channel flags
setudef flag googlenews

# Changed to public '-' so the bot actually listens to the trigger, permissions checked inside!
bind pub - ".news" news_control
bind evnt - init-server news_refresh

# Safe registration using default TLS layer properties
if {[catch {package require tls 1.6}]} {
	putlog "Google News Error: tls package is required for HTTPS connections."
} else {
	if {[package vcompare [package present tls] 1.7] >= 0} {
		::http::register https 443 [list ::tls::socket -autoservername 1]
	} else {
		::http::register https 443 [list ::tls::socket]
	}
}

proc langSel {} {
	switch -exact -- $::newslang {
		1  { set url {hl=en-US&gl=US&ceid=US:en} }
		2  { set url {hl=tr&gl=TR&ceid=TR:tr} }
		3  { set url {hl=fr&gl=FR&ceid=FR:fr} }
		4  { set url {hl=de&gl=DE&ceid=DE:de} }
		5  { set url {hl=en-GB&gl=GB&ceid=GB:en} }
		6  { set url {hl=ru&gl=RU&ceid=RU:ru} }
		7  { set url {hl=it&gl=IT&ceid=IT:it} }
		8  { set url {hl=nl&gl=NL&ceid=NL:nl} }
		9  { set url {hl=en-AU&gl=AU&ceid=AU:en} }
		10 { set url {hl=pt-PT&gl=PT&ceid=PT:pt} }
		11 { set url {hl=ar&gl=AE&ceid=AE:ar} }
		12 { set url {hl=de-AT&gl=AT&ceid=AT:de} }
		13 { set url {hl=fr-BE&gl=BE&ceid=BE:fr} }
		14 { set url {hl=pt-BR&gl=BR&ceid=BR:pt} }
		15 { set url {hl=bg&gl=BG&ceid=BG:bg} }
		16 { set url {hl=en-CA&gl=CA&ceid=CA:en} }
		17 { set url {hl=en-NZ&gl=NZ&ceid=NZ:en} }
		18 { set url {hl=pl&gl=PL&ceid=PL:pl} }
		19 { set url {hl=ro&gl=RO&ceid=RO:ro} }
		20 { set url {hl=cs&gl=CZ&ceid=CZ:cs} }
		21 { set url {hl=no&gl=NO&ceid=NO:no} }
		22 { set url {hl=fr-CH&gl=CH&ceid=CH:fr} }
		23 { set url {hl=sv&gl=SE&ceid=SE:sv} }
		24 { set url {hl=sr&gl=RS&ceid=RS:sr} }
		25 { set url {hl=zh-CN&gl=CN&ceid=CN:zh-Hans} }
		26 { set url {hl=ja&gl=JP&ceid=JP:ja} }
		27 { set url {hl=el&gl=GR&ceid=GR:el} }
		28 { set url {hl=lt&gl=LT&ceid=LT:lt} }
		29 { set url {hl=en-IN&gl=IN&ceid=IN:en} }
		30 { set url {hl=hu&gl=HU&ceid=HU:hu} }
		31 { set url {hl=es-419&gl=AR&ceid=AR:es} }
		32 { set url {hl=id&gl=ID&ceid=ID:id} }
		33 { set url {hl=en-MY&gl=MY&ceid=MY:en} }
		34 { set url {hl=bn&gl=BD&ceid=BD:bn} }
		35 { set url {hl=es-419&gl=MX&ceid=MX:es} }
		36 { set url {hl=en-PK&gl=PK&ceid=PK:en} }
		37 { set url {hl=en-PH&gl=PH&ceid=PH:en} }
		default { set url {hl=en-US&gl=US&ceid=US:en} }
	}
	return "${::googlelink}?$url"
}

proc news_refresh {type} {
	foreach chan [channels] newsbind [binds time] {
		if {([lsearch -exact [channel info $chan] "+googlenews"] != "-1")\
				&& ![string match "*Google:News*" $newsbind]} {
			bind time - "*" Google:News
			return 1
		}
	}
}

proc news_control {nick uhost hand chan text} {
	set cmd [string tolower [lindex [split $text] 0]]
	
	if {$cmd eq "on"} {
		if {![matchattr $hand mnf|oa $chan]} {
			puthelp "privmsg $chan :Error: You do not have permission to enable news tracking."
			return 0
		}
		if {[channel get $chan googlenews]} {
			puthelp "privmsg $chan :News tracker is already enabled @ $chan"
		} else {
			bind time - "*" Google:News
			channel set $chan +googlenews
			puthelp "privmsg $chan :News tracker is now enabled @ $chan (Checks for updates every minute)"
		}
	} elseif {$cmd eq "off"} {
		if {![matchattr $hand mnf|oa $chan]} {
			puthelp "privmsg $chan :Error: You do not have permission to disable news tracking."
			return 0
		}
		if {![channel get $chan googlenews]} {
			puthelp "privmsg $chan :News tracker is already disabled @ $chan"
		} else {
			channel set $chan -googlenews
			puthelp "privmsg $chan :News tracker has been stopped @ $chan"
		}
	} else {
		# Instant On-Demand Mode
		set news [newsdom]
		if {$news eq ""} {
			puthelp "privmsg $chan :Google News: No recent articles found or feed is temporarily unreachable."
			return 0
		}
		set newsdesc [lindex [split $news |] 0]
		set newslink [lindex [split $news |] 1]
		set newstime [lindex [split $news |] end]
		
		if {$::tinyurl >= 1 && [string length $newslink]} {
			set final_link [news_tiny [string trim $newslink]]
		} else {
			set final_link [string trim $newslink]
		}
		
		set ago [expr {[clock seconds] - $newstime}]
		news_print $chan "$newsdesc : $final_link ([duration $ago] ago.)"
	}
	return 0
}

proc getit {url} {
	set ua "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
	if {[catch {set token [http::geturl $url -binary 1 -timeout 15000 -headers [list User-Agent $ua]]} error]} {
		putcmdlog "Google:News Error: [string map [list \n " "] $error]"
		return ""
	}
	
	set ncode [http::ncode $token]
	set status [http::status $token]
	
	if {$status eq "ok" && $ncode == "200"} {
		set data [http::data $token]
		::http::cleanup $token
	} elseif {[regexp {301|302|303|307} $ncode]} {
		upvar #0 $token state
		set redirectUrl ""
		foreach {names values} $state(meta) {
			if {[string tolower $names] eq "location"} {
				set redirectUrl $values
				break
			}
		}
		::http::cleanup $token
		if {$redirectUrl ne ""} {
			if {[catch {set tok [http::geturl $redirectUrl -binary 1 -timeout 15000 -headers [list User-Agent $ua]]} err]} {
				putcmdlog "Google:News Redirect Error: [string map [list \n " "] $err]"
				return ""
			}
			if {[http::status $tok] eq "ok" && [http::ncode $tok] == "200"} {
				set data [http::data $tok]
			}
			::http::cleanup $tok
		}
	} else {
		::http::cleanup $token
	}
	
	if {[info exists data]} {
		return [encoding convertfrom utf-8 $data]
	}
	return ""
}

proc newsdom {} {
	set xmldata [getit [langSel]]
	if {$xmldata eq ""} { return "" }
	
	if {[catch {dom parse $xmldata} document]} {
		putcmdlog "Google:News DOM Parse Error: $document"
		return ""
	}
	
	set root [$document documentElement]
	set news [list]
	foreach id [$root selectNodes "/rss/channel/item"] {
		set dNode [$id selectNodes "description"]
		set pNode [$id selectNodes "pubDate"]
		set lNode [$id selectNodes "link"]
		if {$dNode eq "" || $pNode eq "" || $lNode eq ""} { continue }
		
		set description [$dNode text]
		set pubDate [$pNode text]
		set newsurl [$lNode text]
		lappend news "[dom_trim $description] | [dom_trim $newsurl] | [clock scan [dom_trim $pubDate]]"
	}
	$document delete
	if {[llength $news] == 0} { return "" }
	set listnews [lindex [lsort -integer -decreasing -index end $news] 0]
	return [join [htmlparse::mapEscapes $listnews]]
}

proc news_print {where what} {
	regexp {^(.*?)(http(?:s|)://[^\s]+)(.*?)$} $what - res links _
	set output [textutil::split::splitn $what $::newsmax]
	if {[string match *${links}* $output]} {
		foreach newsout $output { puthelp "privmsg $where :$newsout" }
	} else {
		foreach newsout [textutil::split::splitn $what [string length $res]] { puthelp "privmsg $where :$newsout" }
	}
}

proc dom_trim {str} {
	regsub -all -nocase {(?:<strong>|</strong>|<b>|</b>)} $str "\002" str
	regsub -all -- {<font color="#6f6f6f">(.*?)</font>} $str "(\00304\\1\003)" str
	set str [string map [list &lt\; \u003c &gt\; \u003e &nbsp\; \u0020 \" \u0027] $str]
	regsub -all -- "<.+?>" $str { } str
	regsub -all -- {\s+} $str "\u0020" str
	return [string trim $str]
}

proc news_tiny {link} {
	set tinyurl [getit http://tinyurl.com/api-create.php?[http::formatQuery url $link]]
	if {[info exists tinyurl] && [string length $tinyurl]} {
		return $tinyurl
	} else {
		return $link
	}
}

proc Google:News {args} {
	foreach chan [channels] {
		if {[channel get $chan googlenews]} {
			set news [newsdom]
			if {$news eq ""} { continue }
			set newsdesc [lindex [split $news |] 0]
			set newslink [lindex [split $news |] 1]
			set newstime [lindex [split $news |] end]
			scan $newsdesc {%[^(]} headline
			set headline [string trim $headline]
			if {![string match *${newslink}* $::oldnews] && ($headline ni $::oldnews)\
					&& ([expr {([clock seconds] - ${newstime}) < (${::headlinedelay} * 60)}])} {
				if {$::tinyurl < "1" || ![string length $::tinyurl]} {
					news_print $chan "$newsdesc : $newslink ([duration [expr {[clock seconds] - $newstime}]] ago.)"
				} else {
					news_print $chan "$newsdesc : [news_tiny [string trim $newslink]] ([duration [expr {[clock seconds] - $newstime}]] ago.)"
				}
				set ::oldnews $news
			}
		}
	}
	return 0
}

putlog "Google News Script Fully Fixed by \[ nrt & karakedi \] Loaded - Region: Philippines by \[ asl_pls \]."
