export const atomicsUri = "/public/atomics.wasm";
export const exampleUri = "/public/example.wasm";

export async function sleep(durationInMs)
{
    return new Promise( resolve => { setTimeout( () => { resolve(); }, durationInMs ); } );
}
