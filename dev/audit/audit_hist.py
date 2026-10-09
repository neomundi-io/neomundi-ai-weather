import json,glob,os
ROOT=r"C:\Users\Danielle\Documents\DATASET\7_Widget\neomundi-ai-weather\neomundi-ai-weather"
def L(f): return json.load(open(f,encoding='utf-8-sig'))
files=sorted(glob.glob(os.path.join(ROOT,"data","history","*.json")))[-21:]
hdr=f"{'date':11}{'gen_at':21}{'pv':4}{'mv_id':22}{'bl_cfg':12}{'exp/sys':8}{'d/l':6}{'tot_obs':8}{'scored':7}{'cov':5}{'dcov':5}{'lcov':5}{'cond':16}{'score':6}{'clr':4}{'wch':4}{'uns':4}{'alt':4}{'insuf':6}"
print(hdr)
for f in files:
    d=L(f); ps=d.get('panel_summary',{}); p=d.get('protocol',{}); mv=d.get('methodology_version',{})
    vp=p.get('volume_profile',{}) or {}
    print(f"{os.path.basename(f)[:-5]:11}{d.get('generated_at','')[:19]:21}{str(p.get('version')):4}"
          f"{str(mv.get('id'))+'/'+str(mv.get('protocol_version')):22}{str(d.get('baseline_config_version')):12}"
          f"{str(p.get('expected_observations_per_system')):8}"
          f"{str(p.get('daily_probe_expected'))+'/'+str(p.get('longitudinal_probe_expected')):6}"
          f"{str(ps.get('total_observations'))+'/'+str(ps.get('total_expected_observations')):8}"
          f"{str(ps.get('total_fully_scored')):7}{str(ps.get('panel_coverage')):5}"
          f"{str(ps.get('daily_panel_coverage')):5}{str(ps.get('longitudinal_panel_coverage')):5}"
          f"{str(d.get('global_condition')):16}{str(d.get('global_score')):6}"
          f"{str(ps.get('systems_clear')):4}{str(ps.get('systems_watch')):4}{str(ps.get('systems_unsettled')):4}"
          f"{str(ps.get('systems_alert')):4}{str(ps.get('systems_insufficient_data')):6} vp={vp.get('profile_id')}")
