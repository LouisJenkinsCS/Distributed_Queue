#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>

/*
  A Multiword Compare-And-Swap algorithm, defined in "Practical lock-freedom" chapter 3.2

  Modifications will be attempted to allow multiword reads, writes, and support proper
  memory reclamation. Currently on hold!
*/

#define UNDECIDED 0
#define FAILED 1
#define SUCCESSFUL 2

typedef uint64_t word_t;

// Potential modification: Have the "expected" and "new" be apart of a union
// and add specific types for READ/WRITE/CAS...
// CAS = {e, n}
// Write = {n}
// Read = {r, n}
typedef struct {
  // Number of logical locations
  int N;
  // Address
  word_t **a;
  // Expected
  word_t *e;
  // New
  word_t *n;
  // UNDECIDED, FAILED, SUCCESSFUL
  word_t status;
} MCASDesc;

static int AddressCompare(const void *addr1, const void *addr2);
static void AddressSort(MCASDesc *d);

// Need a global table to register a descriptor with. As well, the same table needs
// to handle proper memory reclamation. Perhaps Hazard Pointers?
static bool isMCASDesc(MCASDesc *d);

// Performs a multiword compare and swap on N positions, where for each
// i in [1..N], where a[i], e[i], and n[i] correspond to each other;
// atomic { if a[i] == e[i] then a[i] = n[i]; }
// We use descriptors so that MCASHelper can allow recursive helping.
bool MCAS(int N, word_t **a, word_t *e, word_t *n);

// Note that MCASRead will ONLY work if the address being read is managed properly
// through the MCASDesc abstraction!
// Idea:
//  curr <- d->a[i]
//  if isMCASDesc(curr) then
//    MCASHelp(curr)
//    continue
//  d->n[i] = curr;
//  if CCAS(d->a[i], curr, d, &d->status) then
//    ...
//
// Later on in MCASHelper when we're performing the decision point for a reader...
//  for (int i = 0; i < d->N; i++)
//    CAS(d->a[i], d, d->n[i])
//
// The above guarantees forward progression in a non-blocking fashion for reads,
// and writes theh same value back after the descriptor is finished. Since d->n[i]
// contains the value read, we can easily return that.
//
// As well since we can return the data we've read after ensuring we have the atomic value
// of those positions, we can lazily defer processing to other threads in terms of cleaning
// up the descriptor.
word_t *MCASRead(word_t *a, int N);

// Note that MCASWrite will ONLY work if the address being written is managed properly
// through the MCASDesc abstraction!
// Idea:
//  curr <- d->a[i]
//  if isMCASDesc(curr) then
//    MCASHelp(curr)
//    continue
//  if CCAS(d->a[i], curr, d, &d->status) then
//    ...
//
// Later on in MCASHelper when we're performing the decision point for a reader...
//  for (int i = 0; i < d->N; i++)
//    CAS(d->a[i], d, d->n[i])
//
// The above guarantees forward progression in a non-blocking fashion for reads,
// and writes theh same value back after the descriptor is finished.
void MCASWrite(word_t *a, int N);

// A recursive helper algorithm; each thread will attempt to set their descriptor to
// claim ownership of a contested location; if another descriptor is encountered,
// then that thread helps to ensure that progress is made.
bool MCASHelp(MCASDesc *d);

static int AddressCompare(const void *addr1, const void *addr2) {
  return (uintptr_t) addr1 - (uintptr_t) addr2;
}

static void AddressSort(MCASDesc *d) {
  qsort(d->a, d->N, sizeof(word_t), AddressCompare);
}



bool MCAS(int N, word_t **a, word_t *e, word_t *n) {
  MCASDesc *d =  malloc(sizeof(*d));
  d->N = N;
  d->a = a;
  d->e = e;
  d->n = n;

  // Impose a global acquisition order to avoid deadlock
  AddressSort(d);
  return MCASHelp(d);
}
