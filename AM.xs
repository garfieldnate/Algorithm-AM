#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

typedef unsigned short USHORT;
typedef unsigned long ULONG;

typedef struct AM_supra {
  USHORT *data;
  USHORT count;
  USHORT next;
  unsigned char touched;
} AM_SUPRA;

typedef struct AM_guts {
  USHORT *lptr[4];
  AM_SUPRA *sptr[4];
  SV **activeVar;
  SV **outcome;
  SV **itemcontextchain;
  HV *itemcontextchainhead;
  HV *subtooutcome;
  HV *contextsize;
  HV *pointers;
  HV *gang;
  SV **sum;
  IV numoutcomes;
} AM_GUTS;

static int AMguts_mgFree(pTHX_ SV *sv, MAGIC *mg) {
  int i;
  AM_GUTS *guts = (AM_GUTS *) SvPVX(mg->mg_obj);
  for (i = 0; i < 4; ++i) {
    Safefree(guts->lptr[i]);
    Safefree(guts->sptr[i][0].data);
    Safefree(guts->sptr[i]);
  }
  return 0;
}

MGVTBL AMguts_vtab = {
  NULL,
  NULL,
  NULL,
  NULL,
  AMguts_mgFree
};

ULONG tens[16];
ULONG ones[16];

normalize(SV *s) {
  ULONG dspace[10];
  ULONG qspace[10];
  char outspace[55];
  ULONG *dividend, *quotient, *dptr, *qptr;
  char *outptr;
  unsigned int outlength = 0;
  ULONG *p = (ULONG *) SvPVX(s);
  STRLEN length = SvCUR(s) / sizeof(ULONG);
  long double nn = 0;
  int j;

  /* you can't put the for block in {}, or it doesn't work
   * ask me for details some time
   */
  for (j = 8; j; --j)
    nn = 65536.0 * nn + (double) *(p + j - 1);

  dividend = &dspace[0];
  quotient = &qspace[0];
  Copy(p, dividend, length, sizeof(ULONG));
  outptr = outspace + 54;

  while (1) {
    ULONG *temp, carry = 0;
    while (length && (*(dividend + length - 1) == 0)) --length;
    if (length == 0) {
      sv_setpvn(s, outptr, outlength);
      break;
    }
    dptr = dividend + length - 1;
    qptr = quotient + length - 1;
    while (dptr >= dividend) {
      unsigned int i;
      *dptr += carry << 16;
      *qptr = 0;
      for (i = 16; i; ) {
	--i;
	if (tens[i] <= *dptr) {
	  *dptr -= tens[i];
	  *qptr += ones[i];
	}
      }
      carry = *dptr;
      --dptr;
      --qptr;
    }
    --outptr;
    *outptr = (char) (0x30 + *dividend) & 0x00ff;
    ++outlength;
    temp = dividend;
    dividend = quotient;
    quotient = temp;
  }

  SvNVX(s) = nn;
  SvNOK_on(s);
}

MODULE = Algorithm::AM		PACKAGE = Algorithm::AM

BOOT:
  {
    ULONG ten = 10;
    ULONG one = 1;
    ULONG *tensptr = &tens[0];
    ULONG *onesptr = &ones[0];
    unsigned int i;
    for (i = 16; i; i--) {
      *tensptr = ten;
      *onesptr = one;
      ++tensptr;
      ++onesptr;
      ten <<= 1;
      one <<= 1;
    }
  }

void
initialize(...)
 PREINIT:
  CV *project;
  AM_GUTS guts; /* NOT A POINTER THIS TIME! (let memory allocate automatically) */
  SV *svguts;
  MAGIC *mg;
  int i;
 PPCODE:
  project = (CV *) SvRV(ST(0));
  guts.activeVar = AvARRAY((AV *) SvRV(ST(1)));
  guts.outcome = AvARRAY((AV *) SvRV(ST(2)));
  guts.itemcontextchain = AvARRAY((AV *) SvRV(ST(3)));
  guts.itemcontextchainhead = (HV *) SvRV(ST(4));
  guts.subtooutcome = (HV *) SvRV(ST(5));
  guts.contextsize = (HV *) SvRV(ST(6));
  guts.pointers = (HV *) SvRV(ST(7));
  guts.gang = (HV *) SvRV(ST(8));
  guts.sum = AvARRAY((AV *) SvRV(ST(9)));
  guts.numoutcomes = av_len((AV *) SvRV(ST(9)));
  for (i = 0; i < 4; ++i) {
    UV v = SvUVX(guts.activeVar[i]);
    Newz(0, guts.lptr[i], 1 << v, USHORT);
    Newz(0, guts.sptr[i], 1 << (v + 1), AM_SUPRA); /* CHANGED */
    Newz(0, guts.sptr[i][0].data, 2, USHORT);
  }
  svguts = newSVpv((char *) &guts, sizeof(AM_GUTS));
  sv_magic((SV *) project, svguts, PERL_MAGIC_ext, NULL, 0);
  SvRMAGICAL_off((SV *) project);
  mg = mg_find((SV *) project, PERL_MAGIC_ext);
  mg->mg_virtual = &AMguts_vtab;
  mg_magical((SV *) project);

void
fillandcount(...)
 PREINIT:
  CV *project;
  AM_GUTS *guts;
  MAGIC *mg;
  USHORT activeVar[4];
  USHORT **lptr;
  AM_SUPRA **sptr;
  USHORT nptr[4];
  USHORT subcontextnumber;
  USHORT *subcontext;
  USHORT *suboutcome;
  SV **outcome, **itemcontextchain, **sum;
  HV *itemcontextchainhead, *subtooutcome, *contextsize, *pointers, *gang;
  IV numoutcomes;
  HE *he;
  ULONG grandtotal[8] = {0, 0, 0, 0, 0, 0, 0, 0};
  SV *tempsv;
  int chunk, i;
  USHORT gaps[16];
  USHORT *intersect, *intersectlist;
  USHORT *intersectlist2, *intersectlist3, *ilist2top, *ilist3top;
 PPCODE:
  project = (CV *) SvRV(ST(0));
  mg = mg_find((SV *) project, PERL_MAGIC_ext);
  guts = (AM_GUTS *) SvPVX(mg->mg_obj);
  lptr = guts->lptr;
  sptr = guts->sptr;
  for (chunk = 0; chunk < 4; ++chunk) {
    activeVar[chunk] = (USHORT) SvUVX(guts->activeVar[chunk]);
    Zero(lptr[chunk], 1 << activeVar[chunk], USHORT);
    sptr[chunk][0].next = 0;
    nptr[chunk] = 1;
    for (i = 1; i < 1 << (activeVar[chunk] + 1); ++i) /* CHANGED */
      sptr[chunk][i].next = (USHORT) i + 1;
  }
  subtooutcome = guts->subtooutcome;
  subcontextnumber = (USHORT) HvUSEDKEYS(subtooutcome);
  Newz(0, subcontext, 4 * (subcontextnumber + 1), USHORT);
  subcontext += 4 * subcontextnumber;
  Newz(0, suboutcome, subcontextnumber + 1, USHORT);
  suboutcome += subcontextnumber;
  Newz(0, intersectlist, subcontextnumber + 1, USHORT);
  Newz(0, intersectlist2, subcontextnumber + 1, USHORT);
  ilist2top = intersectlist2 + subcontextnumber;
  Newz(0, intersectlist3, subcontextnumber + 1, USHORT);
  ilist3top = intersectlist3 + subcontextnumber;

  hv_iterinit(subtooutcome);
  while (he = hv_iternext(subtooutcome)) {
    USHORT *contextptr = (USHORT *) HeKEY(he);
    USHORT outcome = (USHORT) SvUVX(HeVAL(he));
    for (chunk = 0; chunk < 4; ++chunk, ++contextptr) {
      USHORT active = activeVar[chunk];
      USHORT *lattice = lptr[chunk];
      AM_SUPRA *supralist = sptr[chunk];
      USHORT nextsupra = nptr[chunk];
      USHORT context = *contextptr;
      AM_SUPRA *p, *c;
      USHORT pi, ci;
      USHORT d, t, tt, numgaps = 0;

      subcontext[chunk] = context;

      if (context == 0) {
	for (p = supralist + supralist->next;
	     p != supralist; p = supralist + p->next) {
	  USHORT *data;
	  Newz(0, data, p->data[0] + 3, USHORT);
	  Copy(p->data + 2, data + 3, p->data[0], USHORT);
	  data[2] = subcontextnumber;
	  data[0] = p->data[0] + 1;
	  Safefree(p->data);
	  p->data = data;
	}
	if (lattice[context] == 0) {
	  USHORT count = 0;
	  ci = nptr[chunk];
	  nptr[chunk] = supralist[ci].next;
	  c = supralist + ci;
	  c->next = supralist->next;
	  supralist->next = ci;
	  Newz(0, c->data, 3, USHORT);
	  c->data[2] = subcontextnumber;
	  c->data[0] = 1;
	  for (i = 0; i < (1 << active); ++i) {
	    if (lattice[i] == 0) {
	      lattice[i] = ci;
	      ++count;
	    }
	  }
	  c->count = count;
	}
	continue;
      }

      /* set up ancestor/descendant */
      d = context;
      for (i = 1 << (active - 1); i; i >>= 1)
        if (!(i & context))
	  gaps[numgaps++] = i;
      t = 1 << numgaps;

      p = supralist + (pi = lattice[context]);
      if (pi) --(p->count);
      ci = nextsupra;
      nextsupra = supralist[ci].next;
      p->touched = 1;
      c = supralist + ci;
      c->touched = 0;
      c->next = p->next;
      p->next = ci;
      c->count = 1;
      Newz(0, c->data, p->data[0] + 3, USHORT);
      Copy(p->data + 2, c->data + 3, p->data[0], USHORT);
      c->data[2] = subcontextnumber;
      c->data[0] = p->data[0] + 1;
      lattice[context] = ci;

      while (--t) {
  	for (i = 0, tt = ~t & (t - 1); tt; tt >>= 1, ++i);
  	d ^= gaps[i];

	p = supralist + (pi = lattice[d]);
  	if (pi) --(p->count);
  	switch (p->touched) {
  	case 1:
  	  ++supralist[lattice[d] = p->next].count;
  	  break;
  	case 0:
  	  ci = nextsupra;
  	  nextsupra = supralist[ci].next;
  	  p->touched = 1;
  	  c = supralist + ci;
  	  c->touched = 0;
  	  c->next = p->next;
  	  p->next = ci;
  	  c->count = 1;
  	  Newz(0, c->data, p->data[0] + 3, USHORT);
  	  Copy(p->data + 2, c->data + 3, p->data[0], USHORT);
  	  c->data[2] = subcontextnumber;
  	  c->data[0] = p->data[0] + 1;
  	  lattice[d] = ci;
  	}
      }

      p = supralist;
      p->touched = 0;
      do {
        if (supralist[i = p->next].count == 0) {
	  Safefree(supralist[i].data);
  	  p->next = supralist[i].next;
  	  supralist[i].next = nextsupra;
  	  nextsupra = (USHORT) i;
  	} else {
  	  p = supralist + p->next;
  	  p->touched = 0;
  	}
      } while (p->next);
      nptr[chunk] = nextsupra;
    }
    subcontext -= 4;
    *suboutcome = outcome;
    --suboutcome;
    --subcontextnumber;
  }

  contextsize = guts->contextsize;
  pointers = guts->pointers;

  if (SvUVX(ST(1))) {
    /* squared */
    AM_SUPRA *p0, *p1, *p2, *p3;
    USHORT outcome;
    USHORT length;
    unsigned short *temp, *i, *j, *k;

    for (p0 = sptr[0] + sptr[0]->next; p0 != sptr[0]; p0 = sptr[0] + p0->next) {
      for (p1 = sptr[1] + sptr[1]->next; p1 != sptr[1]; p1 = sptr[1] + p1->next) {

	i = p0->data + p0->data[0] + 1;
	j = p1->data + p1->data[0] + 1;
	k = ilist2top;
	while (1) {
	  while (*i > *j) --i;
	  if (*i == 0) break;
	  if (*i < *j) {
	    temp = i;
	    i = j;
	    j = temp;
	    continue;
	  }
	  *k = *i;
	  --i;
	  --j;
	  --k;
	}
	if (k == ilist2top) continue;
	*k = 0;

	for (p2 = sptr[2] + sptr[2]->next; p2 != sptr[2]; p2 = sptr[2] + p2->next) {

	  i = ilist2top;
	  j = p2->data + p2->data[0] + 1;
	  k = ilist3top;
	  while (1) {
	    while (*i > *j) --i;
	    if (*i == 0) break;
	    if (*i < *j) {
	      temp = i;
	      i = j;
	      j = temp;
	      continue;
	    }
	    *k = *i;
	    --i;
	    --j;
	    --k;
	  }
	  if (k == ilist3top) continue;
	  *k = 0;

	  for (p3 = sptr[3] + sptr[3]->next; p3 != sptr[3]; p3 = sptr[3] + p3->next) {
	    outcome = 0;
	    length = 0;
	    intersect = intersectlist;

	    i = ilist3top;
	    j = p3->data + p3->data[0] + 1;
	    while (1) {
	      while (*i > *j) --i;
	      if (*i == 0) break;
	      if (*i < *j) {
		temp = i;
		i = j;
		j = temp;
		continue;
	      }
	      *intersect = *i;
	      ++intersect;
	      ++length;

	      if (outcome == 0) {
		if (length > 1) {
		  length = 0;
		  break;
		} else {
		  outcome = suboutcome[*i];
		}
	      } else {
		if (outcome != suboutcome[*i]) {
		  length = 0;
		  break;
		}
	      }
	      --i;
	      --j;
	    }

	    if (length) {
	      USHORT i;
	      ULONG pointercount = 0;
	      ULONG count[8] = {0, 0, 0, 0, 0, 0, 0, 0};
	      ULONG mask = 0xffff;

	      count[0]  = p0->count;

	      count[0] *= p1->count;
	      count[1] += count[0] >> 16;
	      count[0] &= mask;

	      count[0] *= p2->count;
	      count[1] *= p2->count;
	      count[1] += count[0] >> 16;
	      count[2] += count[1] >> 16;
	      count[0] &= mask;
	      count[1] &= mask;

	      count[0] *= p3->count;
	      count[1] *= p3->count;
	      count[2] *= p3->count;
	      count[1] += count[0] >> 16;
	      count[2] += count[1] >> 16;
	      count[3] += count[2] >> 16;
	      count[0] &= mask;
	      count[1] &= mask;
	      count[2] &= mask;

	      for (i = 0; i < length; ++i)
		pointercount += (ULONG)
		  SvUV(*hv_fetch(contextsize,
				 (char *) (subcontext + (4 * intersectlist[i])),
				 8, 0));
	      if (pointercount & 0xffff0000) {
		USHORT pchi = (USHORT) pointercount >> 16;
		USHORT pclo = (USHORT) pointercount & 0xffff;
		ULONG hiprod[6];
		hiprod[1] = pchi * count[0];
		hiprod[2] = pchi * count[1];
		hiprod[3] = pchi * count[2];
		hiprod[4] = pchi * count[3];
		count[0] *= pclo;
		count[1] *= pclo;
		count[2] *= pclo;
		count[3] *= pclo;
		count[1] += count[0] >> 16;
		count[2] += count[1] >> 16;
		count[3] += count[2] >> 16;
		count[4] += count[3] >> 16;
		count[0] &= mask;
		count[1] &= mask;
		count[2] &= mask;
		count[3] &= mask;
		count[1] += hiprod[1];
		count[2] += hiprod[2];
		count[3] += hiprod[3];
		count[4] += hiprod[4];
		count[2] += count[1] >> 16;
		count[3] += count[2] >> 16;
		count[4] += count[3] >> 16;
		count[5] += count[4] >> 16;
		count[1] &= mask;
		count[2] &= mask;
		count[3] &= mask;
		count[4] &= mask;
	      } else {
		count[0] *= pointercount;
		count[1] *= pointercount;
		count[2] *= pointercount;
		count[3] *= pointercount;
		count[1] += count[0] >> 16;
		count[2] += count[1] >> 16;
		count[3] += count[2] >> 16;
		count[4] += count[3] >> 16;
		count[0] &= mask;
		count[1] &= mask;
		count[2] &= mask;
		count[3] &= mask;
	      }
	      for (i = 0; i < length; ++i) {
		int j;
		SV *tempsv;
		ULONG *p;
		tempsv = *hv_fetch(pointers,
				   (char *) (subcontext + (4 * intersectlist[i])),
				   8, 1);
		if (!SvPOK(tempsv)) {
		  SvUPGRADE(tempsv, SVt_PVNV);
		  SvGROW(tempsv, 8 * sizeof(ULONG) + 1);
		  Zero(SvPVX(tempsv), 8, ULONG);
		  SvCUR_set(tempsv, 8 * sizeof(ULONG));
		  SvPOK_on(tempsv);
		}
		p = (ULONG *) SvPVX(tempsv);
		for (j = 0; j < 7; ++j) {
		  *(p + j) += count[j];
		  *(p + j + 1) += *(p + j) >> 16;
		  *(p + j) &= mask;
		}
	      }
	    }
	  }
	}
      }
    }
    for (p0 = sptr[0] + sptr[0]->next; p0 != sptr[0]; p0 = sptr[0] + p0->next)
      Safefree(p0->data);
    for (p1 = sptr[1] + sptr[1]->next; p1 != sptr[1]; p1 = sptr[1] + p1->next)
      Safefree(p1->data);
    for (p2 = sptr[2] + sptr[2]->next; p2 != sptr[2]; p2 = sptr[2] + p2->next)
      Safefree(p2->data);
    for (p3 = sptr[3] + sptr[3]->next; p3 != sptr[3]; p3 = sptr[3] + p3->next)
      Safefree(p3->data);
  }
  else
  {
    /* linear */
    AM_SUPRA *p0, *p1, *p2, *p3;
    USHORT outcome;
    USHORT length;
    unsigned short *temp, *i, *j, *k;

    for (p0 = sptr[0] + sptr[0]->next; p0 != sptr[0]; p0 = sptr[0] + p0->next) {
      for (p1 = sptr[1] + sptr[1]->next; p1 != sptr[1]; p1 = sptr[1] + p1->next) {

	i = p0->data + p0->data[0] + 1;
	j = p1->data + p1->data[0] + 1;
	k = ilist2top;
	while (1) {
	  while (*i > *j) --i;
	  if (*i == 0) break;
	  if (*i < *j) {
	    temp = i;
	    i = j;
	    j = temp;
	    continue;
	  }
	  *k = *i;
	  --i;
	  --j;
	  --k;
	}
	if (k == ilist2top) continue;
	*k = 0;

	for (p2 = sptr[2] + sptr[2]->next; p2 != sptr[2]; p2 = sptr[2] + p2->next) {

	  i = ilist2top;
	  j = p2->data + p2->data[0] + 1;
	  k = ilist3top;
	  while (1) {
	    while (*i > *j) --i;
	    if (*i == 0) break;
	    if (*i < *j) {
	      temp = i;
	      i = j;
	      j = temp;
	      continue;
	    }
	    *k = *i;
	    --i;
	    --j;
	    --k;
	  }
	  if (k == ilist3top) continue;
	  *k = 0;

	  for (p3 = sptr[3] + sptr[3]->next; p3 != sptr[3]; p3 = sptr[3] + p3->next) {
	    outcome = 0;
	    length = 0;
	    intersect = intersectlist;

	    i = ilist3top;
	    j = p3->data + p3->data[0] + 1;
	    while (1) {
	      while (*i > *j) --i;
	      if (*i == 0) break;
	      if (*i < *j) {
		temp = i;
		i = j;
		j = temp;
		continue;
	      }
	      *intersect = *i;
	      ++intersect;
	      ++length;

	      if (outcome == 0) {
		if (length > 1) {
		  length = 0;
		  break;
		} else {
		  outcome = suboutcome[*i];
		}
	      } else {
		if (outcome != suboutcome[*i]) {
		  length = 0;
		  break;
		}
	      }
	      --i;
	      --j;
	    }

	    if (length) {
	      USHORT i;
	      ULONG count[8] = {0, 0, 0, 0, 0, 0, 0, 0};
	      ULONG mask = 0xffff;

	      count[0]  = p0->count;

	      count[0] *= p1->count;
	      count[1] += count[0] >> 16;
	      count[0] &= mask;

	      count[0] *= p2->count;
	      count[1] *= p2->count;
	      count[1] += count[0] >> 16;
	      count[2] += count[1] >> 16;
	      count[0] &= mask;
	      count[1] &= mask;

	      count[0] *= p3->count;
	      count[1] *= p3->count;
	      count[2] *= p3->count;
	      count[1] += count[0] >> 16;
	      count[2] += count[1] >> 16;
	      count[3] += count[2] >> 16;
	      count[0] &= mask;
	      count[1] &= mask;
	      count[2] &= mask;

	      for (i = 0; i < length; ++i) {
		int j;
		SV *tempsv;
		ULONG *p;
		tempsv = *hv_fetch(pointers,
				   (char *) (subcontext + (4 * intersectlist[i])),
				   8, 1);
		if (!SvPOK(tempsv)) {
		  SvUPGRADE(tempsv, SVt_PVNV);
		  SvGROW(tempsv, 8 * sizeof(ULONG) + 1);
		  Zero(SvPVX(tempsv), 8, ULONG);
		  SvCUR_set(tempsv, 8 * sizeof(ULONG));
		  SvPOK_on(tempsv);
		}
		p = (ULONG *) SvPVX(tempsv);
		for (j = 0; j < 7; ++j) {
		  *(p + j) += count[j];
		  *(p + j + 1) += *(p + j) >> 16;
		  *(p + j) &= mask;
		}
	      }
	    }
	  }
	}
      }
    }
    for (p0 = sptr[0] + sptr[0]->next; p0 != sptr[0]; p0 = sptr[0] + p0->next)
      Safefree(p0->data);
    for (p1 = sptr[1] + sptr[1]->next; p1 != sptr[1]; p1 = sptr[1] + p1->next)
      Safefree(p1->data);
    for (p2 = sptr[2] + sptr[2]->next; p2 != sptr[2]; p2 = sptr[2] + p2->next)
      Safefree(p2->data);
    for (p3 = sptr[3] + sptr[3]->next; p3 != sptr[3]; p3 = sptr[3] + p3->next)
      Safefree(p3->data);
  }

  gang = guts->gang;
  outcome = guts->outcome;
  itemcontextchain = guts->itemcontextchain;
  itemcontextchainhead = guts->itemcontextchainhead;
  sum = guts->sum;
  numoutcomes = guts->numoutcomes;
  hv_iterinit(pointers);
  while (he = hv_iternext(pointers)) {
    ULONG count;
    USHORT counthi, countlo;
    ULONG p[8];
    ULONG gangcount[8];
    USHORT thisoutcome;
    SV *dataitem;
    Copy(SvPVX(HeVAL(he)), p, 8, ULONG);
    tempsv = *hv_fetch(contextsize, HeKEY(he), 4 * sizeof(USHORT), 0);
    count = (ULONG) SvUVX(tempsv);
    counthi = (USHORT) count >> 16;
    countlo = (USHORT) count & 0xffff;
    gangcount[0] = 0;
    for (i = 0; i < 6; ++i) {
      gangcount[i] += countlo * p[i];
      gangcount[i + 1] = gangcount[i] >> 16;
      gangcount[i] &= 0xffff;
    }
    if (counthi) {
      for (i = 0; i < 6; ++i) {
	gangcount[i + 1] += counthi * p[i];
	gangcount[i + 2] += gangcount[i + 1] >> 16;
	gangcount[i + 1] &= 0xffff;
      }
    }
    for (i = 0; i < 7; ++i) {
      grandtotal[i] += gangcount[i];
      grandtotal[i + 1] += grandtotal[i] >> 16;
      grandtotal[i] &= 0xffff;
    }
    grandtotal[7] += gangcount[7];
    tempsv = *hv_fetch(gang, HeKEY(he), 4 * sizeof(USHORT), 1);
    SvUPGRADE(tempsv, SVt_PVNV);
    sv_setpvn(tempsv, (char *) gangcount, 8 * sizeof(ULONG));
    normalize(tempsv);
    normalize(HeVAL(he));

    tempsv = *hv_fetch(subtooutcome, HeKEY(he), 4 * sizeof(USHORT), 0);
    thisoutcome = (USHORT) SvUVX(tempsv);
    if (thisoutcome) {
      ULONG *s = (ULONG *) SvPVX(sum[thisoutcome]);
      for (i = 0; i < 7; ++i) {
	*(s + i) += gangcount[i];
	*(s + i + 1) += *(s + i) >> 16;
	*(s + i) &= 0xffff;
      }
    } else {
      dataitem = *hv_fetch(itemcontextchainhead, HeKEY(he), 4 * sizeof(USHORT), 0);
      while (SvIOK(dataitem)) {
	IV datanum = SvIVX(dataitem);
	IV ocnum = SvIVX(outcome[datanum]);
	ULONG *s = (ULONG *) SvPVX(sum[ocnum]);
	for (i = 0; i < 7; ++i) {
	  *(s + i) += p[i];
	  *(s + i + 1) += *(s + i) >> 16;
	  *(s + i) &= 0xffff;
	  dataitem = itemcontextchain[datanum];
	}
      }
    }
  }
  for (i = 1; i <= numoutcomes; ++i) normalize(sum[i]);
  tempsv = *hv_fetch(pointers, "grandtotal", 10, 1);
  sv_setpvn(tempsv, (char *) grandtotal, 8 * sizeof(ULONG));
  SvUPGRADE(tempsv, SVt_PVNV);
  normalize(tempsv);

  Safefree(subcontext);
  Safefree(suboutcome);
  Safefree(intersectlist);
  Safefree(intersectlist2);
  Safefree(intersectlist3);
