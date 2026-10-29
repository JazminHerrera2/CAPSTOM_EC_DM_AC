const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, deleteDoc, Timestamp } = require('firebase/firestore');
const fs = require('fs');
const test = require('node:test');

let env;
const valido = () => ({
  categoria: 'Talleres', titulo: 'Descuento en frenos', empresa: 'Taller Sur',
  descripcion: 'x', imagen_path: 'beneficios/1730000000_a.png', url_externa: 'https://ej.cl',
  ubicacion: 'Santiago', fecha_inicio: Timestamp.fromDate(new Date(2026, 9, 1)),
  fecha_fin: Timestamp.fromDate(new Date(2026, 11, 31)), condiciones: 'c',
  destacado: false, activo: true,
});

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-tag-ok',
    firestore: { rules: fs.readFileSync(process.env.RULES, 'utf8'), host: '127.0.0.1', port: 8085 },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'administradores/sa'), { rol: 'super_admin', email: 'sa@x.cl' });
    await setDoc(doc(db, 'administradores/op'), { rol: 'operador', email: 'op@x.cl' });
    await setDoc(doc(db, 'administradores/sinrol'), { email: 's@x.cl' });
    await setDoc(doc(db, 'beneficios/b1'), valido());
  });
});
test.after(async () => env.cleanup());

const anon = () => env.unauthenticatedContext().firestore();
const user = () => env.authenticatedContext('u1').firestore();
const sa = () => env.authenticatedContext('sa').firestore();
const op = () => env.authenticatedContext('op').firestore();
const sinrol = () => env.authenticatedContext('sinrol').firestore();

test('a. sin sesion no lee', () => assertFails(getDoc(doc(anon(), 'beneficios/b1'))));
test('b. usuario normal lee', () => assertSucceeds(getDoc(doc(user(), 'beneficios/b1'))));
test('c1. usuario normal no crea', () => assertFails(setDoc(doc(user(), 'beneficios/n1'), valido())));
test('c2. usuario normal no edita', () => assertFails(updateDoc(doc(user(), 'beneficios/b1'), { activo: false })));
test('c3. usuario normal no borra', () => assertFails(deleteDoc(doc(user(), 'beneficios/b1'))));
test('d1. super admin crea valido', () => assertSucceeds(setDoc(doc(sa(), 'beneficios/n2'), valido())));
test('d2. super admin edita (toggle activo)', () => assertSucceeds(updateDoc(doc(sa(), 'beneficios/b1'), { activo: false })));
test('d3. super admin borra', () => assertSucceeds(deleteDoc(doc(sa(), 'beneficios/b1'))));
test('e. categoria invalida rechazada', () => assertFails(setDoc(doc(sa(), 'beneficios/n3'), { ...valido(), categoria: 'Otra' })));
test('f. url_externa sin https rechazada', () => assertFails(setDoc(doc(sa(), 'beneficios/n4'), { ...valido(), url_externa: 'http://ej.cl' })));
test('f2. imagen sin https rechazada', () => assertFails(setDoc(doc(sa(), 'beneficios/n4b'), { ...valido(), imagen_path: 'javascript:alert(1)' })));
test('f3. imagen subida (beneficios/archivo) valida', () => assertSucceeds(setDoc(doc(sa(), 'beneficios/n4c'), { ...valido(), imagen_path: 'beneficios/123_foto.jpg' })));
test('f4. imagen con ruta de otra carpeta rechazada', () => assertFails(setDoc(doc(sa(), 'beneficios/n4d'), { ...valido(), imagen_path: 'usuarios/u1/vehiculos/x/1.jpg' })));
test('f5. imagen con path traversal rechazada', () => assertFails(setDoc(doc(sa(), 'beneficios/n4e'), { ...valido(), imagen_path: 'beneficios/../x.png' })));
test('l1. Otros con texto libre valido', () => assertSucceeds(setDoc(doc(sa(), 'beneficios/n11'), { ...valido(), categoria: 'Otros', categoria_otra: 'Lavado a domicilio' })));
test('l2. Otros sin texto rechazado', () => assertFails(setDoc(doc(sa(), 'beneficios/n12'), { ...valido(), categoria: 'Otros' })));
test('l3. Otros con texto vacio rechazado', () => assertFails(setDoc(doc(sa(), 'beneficios/n13'), { ...valido(), categoria: 'Otros', categoria_otra: '' })));
test('l4. Otros con texto de mas de 60 caracteres rechazado', () => assertFails(setDoc(doc(sa(), 'beneficios/n14'), { ...valido(), categoria: 'Otros', categoria_otra: 'x'.repeat(61) })));
test('l5. categoria_otra con otra categoria rechazada', () => assertFails(setDoc(doc(sa(), 'beneficios/n15'), { ...valido(), categoria_otra: 'algo' })));
test('g. campo extra rechazado', () => assertFails(setDoc(doc(sa(), 'beneficios/n5'), { ...valido(), hack: 1 })));
test('h. fecha_fin < fecha_inicio rechazada', () => assertFails(setDoc(doc(sa(), 'beneficios/n6'), { ...valido(), fecha_inicio: Timestamp.fromDate(new Date(2026, 11, 31)), fecha_fin: Timestamp.fromDate(new Date(2026, 0, 1)) })));
test('h2. sin fechas es valido', () => { const d = valido(); delete d.fecha_inicio; delete d.fecha_fin; return assertSucceeds(setDoc(doc(sa(), 'beneficios/n7'), d)); });
test('i1. operador no escribe', () => assertFails(setDoc(doc(op(), 'beneficios/n8'), valido())));
test('i2. admin sin campo rol no escribe', () => assertFails(setDoc(doc(sinrol(), 'beneficios/n9'), valido())));
test('i3. operador si lee', () => assertSucceeds(getDoc(doc(op(), 'beneficios/b1'))));
test('j. titulo vacio rechazado', () => assertFails(setDoc(doc(sa(), 'beneficios/n10'), { ...valido(), titulo: '' })));
test('k. otras colecciones siguen cerradas (estacionamientos)', () => assertFails(getDoc(doc(user(), 'estacionamientos/x'))));
