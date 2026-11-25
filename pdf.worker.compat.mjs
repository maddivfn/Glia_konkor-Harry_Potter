if(!Promise.withResolvers){Promise.withResolvers=function(){let resolve,reject;const promise=new Promise((ok,fail)=>{resolve=ok;reject=fail});return{promise,resolve,reject}}}
await import('./pdf.worker.min.mjs');
