

// export async function demoAsync(){
//     console.log("A");
//     await sleep1(100);
//     console.log("B");

//      console.log("A");
//      sleep2(100, ()=>{
//         console.log("B");
//      })
// }

// function sleep1(durationInMs){
//     console.log(`start sleep for ${durationInMs}ms`);

//     return new Promise(resolve=>{
//         setTimeout(()=>{
//             console.log(`done sleeping for ${durationInMs}ms`);
//             resolve()
//         }, durationInMs);
//     });

// }

// function sleep2(durationInMs, callback){
//     console.log(`start sleep for ${durationInMs}ms`);
//     setTimeout(()=>{
//         console.log(`done sleeping for ${durationInMs}ms`);
//         callback()
//     }, durationInMs);

// }