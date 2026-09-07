"""Generate the IR Lab PBIP and verify the source extract (Python standard library).
Run from any directory. Use --project-root only to set Desktop's import location.
Re-run build_peers.R first after changing the source data. Generated PBIR is overwritten.
"""
import argparse, csv, hashlib, json, math, statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'powerbi'
parser = argparse.ArgumentParser()
parser.add_argument('--project-root', default=str(ROOT))
args = parser.parse_args()
project_root = str(Path(args.project_root)).replace('\\', '/').rstrip('/')

def write(path, obj):
    p = OUT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')

def read(name):
    with (ROOT / name).open(encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f))

rows = read('data/institutions.csv')
peers = read('powerbi/data/peers.csv')
dictionary = {r['variable']: r for r in read('data/variables.csv')}
fields = list(rows[0])
assert set(fields) == set(dictionary)
assert len({r['unitid'] for r in rows}) == len(rows)
assert all(r['unitid'] for r in rows)
text_cols = set(fields[:13]) - {'unitid'}
int_cols = {'unitid','headcount','undergrad','stu_fac_ratio','grad_cohort','bach_cohort',
            'aid_cohort','associates_awarded','bachelors_awarded','masters_awarded','doctorates_awarded'}
int_cols |= {f for f in fields if f.startswith('net_price')}
rate_cols = [f for f in fields if f.startswith(('pct_', 'grad_rate')) or f.startswith('retention_')]
for r in rows:
    for f in set(fields) - text_cols:
        if r[f]:
            assert math.isfinite(float(r[f])), (r['unitid'], f)
            if f in rate_cols: assert 0 <= float(r[f]) <= 100, (r['unitid'], f)
features = ['pct_pell','grad_rate_bach_6yr','net_price','retention_ft','stu_fac_ratio']
expected = {r['unitid']:r for r in rows if r['level']=='4-year' and r['control'] in ['Public','Private nonprofit'] and r['bach_cohort'] and float(r['bach_cohort'])>=100 and all(r[f] for f in features)}
assert len(peers) == len(expected) == len({r['unitid'] for r in peers})
for r in peers:
    assert r['unitid'] in expected
    for f in features:
        assert float(r[f]) == float(expected[r['unitid']][f]), 'Rebuild peers: source changed'
assert set(r['peer_group'] for r in peers) == {'Group 1','Group 2','Group 3','Group 4'}

BASE = 'https://developer.microsoft.com/json-schemas/fabric/item/'
def schema(kind, version): return BASE + 'report/definition/' + kind + '/' + version + '/schema.json'
write('IR Lab.pbip', {'$schema':'https://developer.microsoft.com/json-schemas/fabric/pbip/pbipProperties/1.0.0/schema.json','version':'1.0','artifacts':[{'report':{'path':'IR Lab.Report'}}],'settings':{'enableAutoRecovery':True}})
write('IR Lab.Report/definition.pbir', {'$schema':BASE+'report/definitionProperties/2.0.0/schema.json','version':'4.0','datasetReference':{'byPath':{'path':'../IR Lab.SemanticModel'}}})
write('IR Lab.SemanticModel/definition.pbism', {'$schema':BASE+'semanticModel/definitionProperties/1.0.0/schema.json','version':'4.0','settings':{}})

def measure(name, dax, fmt='#,0', description=''):
    return {'name':name,'expression':dax,'formatString':fmt,'description':description}

completion = 'FILTER ( institutions, institutions[level] = "4-year" && NOT ISBLANK ( institutions[grad_rate_bach_6yr] ) )'
fit = 'FILTER ( institutions, institutions[level] = "4-year" && institutions[bach_cohort] >= 30 && NOT ISBLANK ( institutions[pct_pell] ) && NOT ISBLANK ( institutions[grad_rate_bach_6yr] ) )'
measures = [
    measure('Institutions','COUNTROWS ( institutions )',description='Active institutions in the current filter context; one row per UNITID.'),
    measure('Completion Institutions',f'COUNTROWS ( {completion} )'),
    measure('Mean Completion',f'AVERAGEX ( {completion}, institutions[grad_rate_bach_6yr] )','0.0"%"','Unweighted mean of institution rates, stored on a 0â€“100 scale. Not a student-level graduation rate.'),
    measure('Median Completion',f'MEDIANX ( {completion}, institutions[grad_rate_bach_6yr] )','0.0"%"'),
    measure('Completion SD',f'VAR t = {completion}\nRETURN IF ( COUNTROWS ( t ) > 1, STDEVX.S ( t, institutions[grad_rate_bach_6yr] ) )','0.0" pp"'),
    measure('Completion Missing', 'COUNTROWS ( FILTER ( institutions, institutions[level] = "4-year" && ISBLANK ( institutions[grad_rate_bach_6yr] ) ) )'),
    measure('Completion Skewness',f'VAR t = {completion}\nVAR n = COUNTROWS ( t )\nVAR m = AVERAGEX ( t, institutions[grad_rate_bach_6yr] )\nVAR s = IF ( n > 1, STDEVX.S ( t, institutions[grad_rate_bach_6yr] ) )\nRETURN IF ( n > 2 && s > 0, AVERAGEX ( t, POWER ( DIVIDE ( institutions[grad_rate_bach_6yr] - m, s ), 3 ) ) )','0.000','Lesson definition: mean cubed standardized deviation using sample SD; differs from Excel adjusted SKEW.'),
    measure('Median Net Price','MEDIAN ( institutions[net_price] )','$#,0','2022â€“23; median of institution-level average net prices; in-state at public institutions.'),
    measure('Regression Institutions',f'COUNTROWS ( {fit} )'),
]
for name, output, fmt in [('Pell Slope','Slope1','0.000" pp/pp"'),('Pell Intercept','Intercept','0.00" pp"'),('Pell R Squared','CoefficientOfDetermination','0.000'),('Residual SE','StandardError','0.00" pp"')]:
    measures.append(measure(name,f'VAR t = {fit}\nVAR n = COUNTROWS ( t )\nVAR sx = IF ( n > 1, STDEVX.S ( t, institutions[pct_pell] ) )\nRETURN IF ( n > 2 && sx > 0, MAXX ( LINESTX ( t, institutions[grad_rate_bach_6yr], institutions[pct_pell] ), [{output}] ) )',fmt,'Unweighted OLS; four-year institutions, bachelor cohort >=30, complete Pell and completion. Refit within current filters.'))

def import_table(name, csv_path, names, ms):
    columns=[]
    for f in names:
        typ='string' if f in text_cols or f=='peer_group' else ('int64' if f in int_cols or f=='peer_group_sort' else 'double')
        c={'name':f,'dataType':typ,'sourceColumn':f,'summarizeBy':'none'}
        if f in dictionary: c['description']=dictionary[f]['label']+' | '+dictionary[f]['source']+' | '+dictionary[f]['ipeds']
        if f in rate_cols: c['formatString']='0.0"%"'
        elif f.startswith('net_price'): c['formatString']='$#,0'
        elif typ=='int64': c['formatString']='#,0'
        if f=='unitid': c['isKey']=True
        if f=='peer_group': c['sortByColumn']='peer_group_sort'
        columns.append(c)
    types=', '.join('{"'+f+'", '+('type text' if c['dataType']=='string' else 'Int64.Type' if c['dataType']=='int64' else 'type number')+'}' for f,c in zip(names,columns))
    expr=['let',f'    Source = Csv.Document(File.Contents(ProjectRoot & "/{csv_path}"), [Delimiter=",", Encoding=65001, QuoteStyle=QuoteStyle.Csv]),','    Headers = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),','    Nulls = Table.ReplaceValue(Headers, "", null, Replacer.ReplaceValue, Table.ColumnNames(Headers)),',f'    Typed = Table.TransformColumnTypes(Nulls, {{{types}}}, "en-US")','in','    Typed']
    return {'name':name,'columns':columns,'measures':ms,'partitions':[{'name':name,'mode':'import','source':{'type':'m','expression':expr}}]}

inst = import_table('institutions','data/institutions.csv',fields,measures)
inst['columns'] += [
    {'name':'Completion Bin Sort','dataType':'int64','type':'calculated','expression':'VAR r = institutions[grad_rate_bach_6yr] RETURN IF ( ISBLANK ( r ), BLANK (), MIN ( 95, FLOOR ( r, 5 ) ) )','summarizeBy':'none','isHidden':True},
    {'name':'Completion Bin','dataType':'string','type':'calculated','expression':'VAR r = institutions[grad_rate_bach_6yr] VAR lo = institutions[Completion Bin Sort] RETURN IF ( ISBLANK ( r ), BLANK (), FORMAT ( lo, "0" ) & IF ( lo = 95, "â€“100", "â€“<" & FORMAT ( lo + 5, "0" ) ) )','sortByColumn':'Completion Bin Sort','summarizeBy':'none'},
    {'name':'Distribution Eligible','dataType':'int64','type':'calculated','expression':'IF ( institutions[level] = "4-year" && NOT ISBLANK ( institutions[grad_rate_bach_6yr] ), 1, 0 )','summarizeBy':'none','isHidden':True},
    {'name':'Regression Eligible','dataType':'int64','type':'calculated','expression':'IF ( institutions[level] = "4-year" && institutions[bach_cohort] >= 30 && NOT ISBLANK ( institutions[pct_pell] ) && NOT ISBLANK ( institutions[grad_rate_bach_6yr] ), 1, 0 )','summarizeBy':'none','isHidden':True}
]
peer_ms=[measure('Peer Institutions','COUNTROWS ( peers )'), measure('Peer Groups','DISTINCTCOUNT ( peers[peer_group] )')]
for n,f,fmt in [('Peer Median Pell','pct_pell','0.0"%"'),('Peer Median Completion','grad_rate_bach_6yr','0.0"%"'),('Peer Median Net Price','net_price','$#,0'),('Peer Median Retention','retention_ft','0.0"%"'),('Peer Median Student Faculty Ratio','stu_fac_ratio','0.0')]:
    peer_ms.append(measure(n,f'MEDIAN ( peers[{f}] )',fmt))
model={'name':'IR Lab','compatibilityLevel':1600,'model':{'culture':'en-US','defaultPowerBIDataSourceVersion':'powerBI_V3','sourceQueryCulture':'en-US','dataAccessOptions':{'legacyRedirects':True,'returnErrorValuesAsNull':True},'expressions':[{'name':'ProjectRoot','kind':'m','expression':'"'+project_root+'" meta [IsParameterQuery=true, Type="Text", IsParameterQueryRequired=true]'}],'tables':[inst,import_table('peers','powerbi/data/peers.csv',list(peers[0]),peer_ms)],'annotations':[{'name':'PBI_QueryOrder','value':'["ProjectRoot","institutions","peers"]'},{'name':'IRLabSourceSHA256','value':hashlib.sha256((ROOT/'data/institutions.csv').read_bytes()).hexdigest()}]}}
write('validation/model-definition.json',model)
# Emit TMDL so the installed Microsoft Modeling MCP can parse the model offline.
def tmdl(path, lines):
    target = OUT / 'IR Lab.SemanticModel/definition' / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text('\n'.join(lines)+'\n', encoding='utf-8')
def q(name): return "'" + name.replace("'", "''") + "'"
tmdl('database.tmdl', ['database', '\tcompatibilityLevel: 1600'])
tmdl('model.tmdl', ['model Model', '\tculture: en-US', '\tdefaultPowerBIDataSourceVersion: powerBI_V3', '\tsourceQueryCulture: en-US', '\tdataAccessOptions', '\t\tlegacyRedirects', '\t\treturnErrorValuesAsNull', '', 'ref table institutions', 'ref table peers'])
tmdl('expressions.tmdl', ['expression ProjectRoot = ' + model['model']['expressions'][0]['expression']])
for table in model['model']['tables']:
    lines=['table '+q(table['name'])]
    for m in table['measures']:
        lines += ['', '\t/// '+m.get('description','').replace('\n',' '), '\tmeasure '+q(m['name'])+' ='] + ['\t\t'+v for v in m['expression'].splitlines()]
        lines += ['\t\tformatString: '+m['formatString']]
    for c in table['columns']:
        expr = ' = '+c['expression'] if c.get('type')=='calculated' else ''
        lines += ['', '\t/// '+c.get('description', c['name']).replace('\n',' '), '\tcolumn '+q(c['name'])+expr, '\t\tdataType: '+c['dataType']]
        if c.get('isKey'): lines += ['\t\tisKey']
        if c.get('isHidden'): lines += ['\t\tisHidden']
        if 'sourceColumn' in c: lines += ['\t\tsourceColumn: '+c['sourceColumn']]
        if 'formatString' in c: lines += ['\t\tformatString: '+c['formatString']]
        if 'sortByColumn' in c: lines += ['\t\tsortByColumn: '+q(c['sortByColumn'])]
        lines += ['\t\tsummarizeBy: none']
    part=table['partitions'][0]
    lines += ['', '\tpartition '+q(table['name'])+' = m', '\t\tmode: import', '\t\tsource =']
    lines += ['\t\t\t'+v for v in part['source']['expression']]
    tmdl('tables/'+table['name']+'.tmdl', lines)


theme={'name':'IR Lab','dataColors':['#2a78d6','#eb6834','#1baf7a','#9b62b3'],'background':'#f8f9fc','foreground':'#14213d','tableAccent':'#2a78d6','textClasses':{'title':{'fontFace':'Segoe UI','fontSize':15,'color':'#14213d'},'label':{'fontFace':'Segoe UI','fontSize':11,'color':'#5c6674'},'callout':{'fontFace':'Segoe UI','fontSize':30,'color':'#14213d'}},'visualStyles':{'*':{'*':{'background':[{'color':{'solid':{'color':'#ffffff'}},'transparency':0}],'border':[{'show':True,'color':{'solid':{'color':'#dde2ea'}},'radius':8}],'visualHeader':[{'show':True}]}}}}
write('IR Lab.Report/StaticResources/RegisteredResources/IRLab.json',theme)
write('IR Lab.Report/definition/version.json',{'$schema':schema('versionMetadata','1.0.0'),'version':'2.0.0'})
write('IR Lab.Report/definition/report.json',{'$schema':schema('report','2.0.0'),'themeCollection':{'customTheme':{'name':'IRLab','reportVersionAtImport':'2.0.0','type':'RegisteredResources'}},'resourcePackages':[{'name':'RegisteredResources','type':'RegisteredResources','items':[{'name':'IRLab','path':'IRLab.json','type':'CustomTheme'}]}],'settings':{'useStylableVisualContainerHeader':True,'exportDataMode':'AllowSummarized','defaultDrillFilterOtherVisuals':True}})

def lit(v):
    return {'expr':{'Literal':{'Value':("'"+v.replace("'","''")+"'") if isinstance(v,str) else str(v).lower()}}}
def column(table, name): return {'Column':{'Expression':{'SourceRef':{'Entity':table}},'Property':name}}
def proj(table,name,kind='column',label=None):
    field = column(table,name) if kind=='column' else {'Measure':{'Expression':{'SourceRef':{'Entity':table}},'Property':name}}
    if kind=='avg': field={'Aggregation':{'Expression':column(table,name),'Function':1}}
    return {'field':field,'queryRef':table+'.'+name,'nativeQueryRef':name,'displayName':label or name}
def cp(n,label=None,t='institutions'): return proj(t,n,label=label)
def mp(n,t='institutions'): return proj(t,n,'measure')
def ap(n,label=None,t='institutions'): return proj(t,n,'avg',label)

pages=[]
def page(name,title,eligibility=None):
    pages.append(name)
    obj={'$schema':schema('page','2.0.0'),'name':name,'displayName':title,'displayOption':'FitToPage','width':1280,'height':900,'objects':{'background':[{'properties':{'color':{'solid':{'color':lit('#f8f9fc')}},'transparency':lit(0)}}]}}
    if eligibility:
        obj['filterConfig']={'filters':[{'name':name+'Eligibility','field':column('institutions',eligibility),'type':'Categorical','filter':{'Version':2,'From':[{'Name':'i','Entity':'institutions','Type':0}],'Where':[{'Condition':{'In':{'Expressions':[{'Column':{'Expression':{'SourceRef':{'Source':'i'}},'Property':eligibility}}],'Values':[[{'Literal':{'Value':'1L'}}]]}}}]}}]}
    write(f'IR Lab.Report/definition/pages/{name}/page.json',obj)
    return name

def visual(p,name,typ,title,pos,roles=None,subtitle=None,objects=None,sort=None):
    x,y,w,h=pos
    v={'$schema':schema('visualContainer','2.1.0'),'name':name,'position':{'x':x,'y':y,'width':w,'height':h,'z':len(list((OUT/f'IR Lab.Report/definition/pages/{p}').glob('visuals/*'))),'tabOrder':y*10+x},'visual':{'visualType':typ,'visualContainerObjects':{'title':[{'properties':{'show':lit(True),'text':lit(title),'fontSize':lit(14),'titleWrap':lit(True)}}]}}}
    if subtitle: v['visual']['visualContainerObjects']['subTitle']=[{'properties':{'show':lit(True),'text':lit(subtitle),'fontSize':lit(10),'titleWrap':lit(True)}}]
    if roles:
        v['visual']['query']={'queryState':{role:{'projections':pr} for role,pr in roles.items()}}
        if sort: v['visual']['query']['sortDefinition']={'sort':[{'field':sort,'direction':'Ascending'}],'isDefaultSort':True}
    if objects: v['visual']['objects']=objects
    write(f'IR Lab.Report/definition/pages/{p}/visuals/{name}/visual.json',v)
def banner(p,title,sub):
    visual(p,'heading','textbox',title,(24,14,1232,92),objects={'general':[{'properties':{'paragraphs':[{'textRuns':[{'value':sub,'textStyle':{'fontSize':'12pt','color':'#5c6674'}}]}]}}]})
def slicers(p,table='institutions',second='state'):
    for j,(f,title) in enumerate([('control','Institution control'),(second,second.replace('_',' ').title())]):
        visual(p,'slicer'+str(j),'slicer',title,(872+j*196,120,188,98),{'Values':[cp(f,t=table)]},objects={'data':[{'properties':{'mode':lit('Dropdown')}}],'selection':[{'properties':{'singleSelect':lit(False)}}]})
def cards(p,names,table='institutions'):
    w=(824-16*(len(names)-1))/len(names)
    for j,n in enumerate(names): visual(p,'card'+str(j),'card',n,(24+j*(w+16),120,w,98),{'Values':[mp(n,table)]})
def bars(p,name,title,pos,cat,val,subtitle=None,sort=None):
    visual(p,name,'clusteredBarChart',title,pos,{'Category':[cat],'Y':[val]},subtitle,objects={'valueAxis':[{'properties':{'start':lit(0)}}]},sort=sort)

p=page('ReportSectionOverview','01 Â· Institution overview')
banner(p,'IR LAB / Institution overview','IPEDS 2023â€“24 collection â€¢ Cross-sectional institution data â€¢ Aid and awards: 2022â€“23; retention: fall 2022â†’2023')
cards(p,['Institutions','Completion Institutions','Median Net Price'])
slicers(p,second='level')
bars(p,'sectors','Institutions by sector',(24,238,746,362),cp('sector','Sector'),mp('Institutions'))
bars(p,'completion','Median six-year completion by control',(790,238,466,362),cp('control','Control'),mp('Median Completion'),'Four-year institutions with reported rates; unweighted median')
visual(p,'lookup','tableEx','Institution lookup',(24,620,1232,258),{'Values':[cp('name','Institution'),cp('state','State'),cp('sector','Sector'),cp('headcount','12-month enrollment'),cp('bach_cohort','Bachelor cohort'),cp('grad_rate_bach_6yr','6-year completion'),cp('net_price','Net price (2022â€“23)')]})

p=page('ReportSectionDistributions','02 Â· Completion distributions','Distribution Eligible')
banner(p,'EXPLORE / The shape of a rate','Four-year institutions with reported six-year bachelor completion â€¢ Each institution has equal weight â€¢ Rates use a 0â€“100 scale')
cards(p,['Completion Institutions','Mean Completion','Median Completion'])
slicers(p)
visual(p,'histogram','clusteredColumnChart','Six-year completion distribution',(24,238,806,378),{'Category':[cp('Completion Bin','Completion rate (%)')],'Y':[mp('Completion Institutions')]},'5 percentage-point bins; last bin includes 100%',objects={'valueAxis':[{'properties':{'start':lit(0)}}]},sort=column('institutions','Completion Bin'))
bars(p,'controlMedians','Median completion by control',(850,238,406,378),cp('control','Control'),mp('Median Completion'))
visual(p,'cohort','slicer','Minimum / maximum bachelor cohort',(24,636,390,110),{'Values':[cp('bach_cohort','Bachelor cohort')]},'Use to examine small-cohort sensitivity')
visual(p,'spread','card','Sample standard deviation',(434,636,390,110),{'Values':[mp('Completion SD')]})
visual(p,'skew','card','Completion skewness',(844,636,412,110),{'Values':[mp('Completion Skewness')]},'Lesson definition; sample SD, unadjusted third moment')
visual(p,'note','textbox','Read the distribution',(24,766,1232,112),objects={'general':[{'properties':{'paragraphs':[{'textRuns':[{'value':'Blank rates are excluded, never changed to zero. All cohorts are included initially. The cohort slicer changes every statistic on this page. The median describes a typical institution, not the probability that a randomly selected student graduates.','textStyle':{'fontSize':'12pt'}}]}]}}]})

p=page('ReportSectionRegression','03 Â· Pell and completion','Regression Eligible')
banner(p,'TEST / A line through the cloud','Four-year institutions â€¢ Bachelor cohort â‰¥30 â€¢ Complete Pell and completion values â€¢ Association across institutions; no causal claim')
cards(p,['Regression Institutions','Pell Slope','Pell R Squared'])
slicers(p)
visual(p,'scatter','scatterChart','Pell share and six-year completion',(24,238,826,400),{'Category':[cp('unitid','Institution ID')],'X':[ap('pct_pell','Pell share (%)')],'Y':[ap('grad_rate_bach_6yr','Six-year completion (%)')],'Tooltips':[cp('name','Institution'),ap('bach_cohort','Bachelor cohort')]},'One dot per institution â€¢ Slicer selections refit the OLS cards',objects={'categoryAxis':[{'properties':{'start':lit(0),'end':lit(100)}}],'valueAxis':[{'properties':{'start':lit(0),'end':lit(100)}}]})
visual(p,'intercept','card','Pell intercept',(870,238,386,184),{'Values':[mp('Pell Intercept')]})
visual(p,'error','card','Residual standard error',(870,442,386,196),{'Values':[mp('Residual SE')]},'Typical residual size, in percentage points')
visual(p,'details','tableEx','Institutions in the fit',(24,658,1232,220),{'Values':[cp('name','Institution'),cp('state','State'),cp('control','Control'),cp('pct_pell','Pell share (%)'),cp('grad_rate_bach_6yr','Completion (%)'),cp('bach_cohort','Bachelor cohort')]})

p=page('ReportSectionPeers','04 Â· Peer groups')
banner(p,'MODEL / Peer groups','Fixed R snapshot â€¢ Four-year public/nonprofit â€¢ Bachelor cohort â‰¥100 â€¢ Five complete standardized features â€¢ k=4, seed=2023, 25 starts')
cards(p,['Peer Institutions','Peer Groups','Peer Median Net Price'],'peers')
slicers(p,'peers','peer_group')
visual(p,'peerScatter','scatterChart','Peer groups in two of the five dimensions',(24,238,806,358),{'Category':[cp('unitid','Institution ID','peers')],'Series':[cp('peer_group','Peer group','peers')],'X':[ap('pct_pell','Pell share (%)','peers')],'Y':[ap('grad_rate_bach_6yr','Completion (%)','peers')],'Tooltips':[cp('name','Institution','peers'),ap('net_price','Net price','peers')]},'Slicers select existing groups; they do not refit k-means',objects={'categoryAxis':[{'properties':{'start':lit(0),'end':lit(100)}}],'valueAxis':[{'properties':{'start':lit(0),'end':lit(100)}}]})
bars(p,'groupSizes','Institutions per peer group',(850,238,406,358),cp('peer_group','Peer group','peers'),mp('Peer Institutions','peers'))
visual(p,'profiles','tableEx','Profile groups in original units',(24,616,1232,262),{'Values':[cp('peer_group','Peer group','peers')]+[mp(n,'peers') for n in ['Peer Institutions','Peer Median Pell','Peer Median Completion','Peer Median Net Price','Peer Median Retention','Peer Median Student Faculty Ratio']]},'Medians of selected institutions â€¢ Group numbers are ordered by standardized Pell center, not quality')
write('IR Lab.Report/definition/pages/pages.json',{'$schema':schema('pagesMetadata','1.0.0'),'pageOrder':pages,'activePageName':pages[0]})

four=[r for r in rows if r['level']=='4-year' and r['grad_rate_bach_6yr']]
reg=[r for r in four if r['pct_pell'] and r['bach_cohort'] and float(r['bach_cohort'])>=30]
x=[float(r['pct_pell']) for r in reg]; y=[float(r['grad_rate_bach_6yr']) for r in reg]
slope,intercept=statistics.linear_regression(x,y)
sst=sum((v-statistics.mean(y))**2 for v in y)
sse=sum((b-intercept-slope*a)**2 for a,b in zip(x,y))
bins={str(i):0 for i in range(0,100,5)}
for r in four: bins[str(min(95,int(float(r['grad_rate_bach_6yr'])//5)*5))]+=1
assert sum(bins.values())==len(four)
manifest={'source':'../data/institutions.csv','source_sha256':hashlib.sha256((ROOT/'data/institutions.csv').read_bytes()).hexdigest(),'source_last_modified_utc':__import__('datetime').datetime.fromtimestamp((ROOT/'data/institutions.csv').stat().st_mtime,__import__('datetime').timezone.utc).isoformat(),'grain':'One row per institution (UNITID); mixed reporting periods, no time series','rows':len(rows),'columns':len(fields),'distribution_rows':len(four),'regression_rows':len(reg),'peer_rows':len(peers),'completion_mean':statistics.mean(float(r['grad_rate_bach_6yr']) for r in four),'completion_median':statistics.median(float(r['grad_rate_bach_6yr']) for r in four),'ols':{'slope':slope,'intercept':intercept,'r_squared':1-sse/sst,'residual_se':math.sqrt(sse/(len(reg)-2))},'histogram_bins_lower_bounds':bins,'nulls':{f:sum(not r[f] for r in rows) for f in fields},'report_pages':pages,'desktop_open_verified':False}
write('validation/source-checks.json',manifest)
print(json.dumps({k:manifest[k] for k in ['rows','columns','distribution_rows','regression_rows','peer_rows','ols']},indent=2))
