// Appended to the generated palette/parts by naomi-build-pixel.py.
function clamp(x,lo,hi) { return Math.max(lo,Math.min(hi,x)); }
function rgb(hex) { return [parseInt(hex.slice(1,3),16),parseInt(hex.slice(3,5),16),parseInt(hex.slice(5,7),16)]; }
function hex(c) { return '#' + c.map(v=>Math.round(clamp(v,0,255)).toString(16).padStart(2,'0')).join(''); }
function paletteFor(accent,soft) {
    const a=[accent.r*255,accent.g*255,accent.b*255],s=[soft.r*255,soft.g*255,soft.b*255];
    const sl=Math.max(1,s[0]*0.2126+s[1]*0.7152+s[2]*0.0722);
    return originalPalette.map((c,i)=>{
        if(i===0 || colorRoles[i]==='fixed')return c;
        const p=rgb(c),l=p[0]*0.2126+p[1]*0.7152+p[2]*0.0722;
        if(colorRoles[i]==='accent')return hex(a.map(v=>v*l/180));
        // A light hue tint, retaining the approved clothing's luminosity and folds.
        return hex(p.map((v,k)=>v*0.60 + l*(s[k]/sl)*0.40));
    });
}
function raster(pose) {
    pose=pose||{};
    const grid=new Array(width*height).fill(0),rise=pose.rise||0,look=pose.look||0;
    function put(x,y,c) {if(x>=0&&x<width&&y>=0&&y<height)grid[y*width+x]=c;}
    function draw(name) {
        for(const run of parts[name])for(let i=0;i<run[2];i++) {
            let x=run[0]+i,y=run[1],dx=0,dy=0;
            if(name==='ponytail') {dx=Math.round((pose.tail||0)*clamp((y-15)/72,0,1));dy=-rise;}
            if(name==='torso')dy=-rise;
            if(name==='head'){dx=look;dy=-rise;}
            if(name==='locks'){dx=look+Math.round((pose.fringe||0)*clamp((y-51)/28,0,1));dy=-rise;}
            if(name==='ribbon'){dx=look+Math.round((pose.ribbon||0)*clamp((y-14)/28,0,1));dy=-rise;}
            put(x+dx,y+dy,run[3]);
        }
    }
    for(const name of ['ponytail','lower','torso','head','locks','ribbon'])draw(name);
    if(pose.blink || pose.happy)for(const p of closedEyes)put(p[0]+look,p[1]-rise,p[2]);
    return grid;
}
function render(pose) {
    const grid=raster(pose),runs=[];
    for(let y=0;y<height;y++)for(let x=0;x<width;){
        const c=grid[y*width+x];let end=x+1;
        while(end<width&&grid[y*width+end]===c)end++;
        if(c)runs.push([x,y,end-x,c]);x=end;
    }
    return runs;
}
