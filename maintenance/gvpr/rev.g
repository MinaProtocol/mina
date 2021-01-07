BEG_G {
graph_t sg = subg ($, "reachable");
$tvtype = TV_rev;
$tvroot = node($,ARGV[0]);
}

N {$tvroot = NULL; subnode (sg, $); }
