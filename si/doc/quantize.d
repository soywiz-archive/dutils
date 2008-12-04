// see quantize.c

const int DEFAULT_PREC = 4;
const int DEFAULT_FRACTION = 5;
const int DEFAULT_MAXSWAPS = 16;
const int DEFAULT_MINDIFF = 9;

struct NODE {
   NODE *next;
   int color, count;
}

struct ITEM {
	int color;
	int key;

	int opCmp(ITEM that) {
		return that.key - this.key;
	}
}

static int distinct;
static NODE[1031] hash_table;

static void delete_list(NODE* list) {
	NODE* node, next;

	for (node = list; node != NULL; node = next) {
		next = node->next;
		delete node;
	}
}

static void insert_node(int color) {
	NODE* p;

	p = &hash_table[color % hash_table.length];

	while (true) {
		if (p->color == color) {
			// this node (e.g. the color was already filled)
			p->count++;
			return;
		}
		if (!p->next) break;
		p = p->next;
	}

	// new color
	if (p->count) {
		p->next = _AL_MALLOC(sizeof(NODE));
		p = p->next;
	}
	
	if (p != NULL) {
		p->color = color;
		p->count = 1;
		p->next = NULL;
		distinct++;
	}
}

/* compare two color values */
static int compare_cols(int col1, int col2) {
	return RGBA.dist(RGBA(col1), RGBA(col2));
}

/* Searches the array from 'item'th field comparing any pair of items.
 * Fills 'key' field of all items >= 'item'th with the difference
 * value (the smallest difference between the checked color and all
 * already used). Than only the last added item has to be compared with
 * all other not yet added colors, what is performed afterwards.
 */
static void optimize_colors(ITEM *array, int item, int palsize, int length, int mindiff)
{
   int i, j, best, curbest, bestpos, t;

   /* iterate through the array comparing any item behind 'item' */
   for (i=item; i<length; i++) {

      /* with all item in front of 'item' */
      for (j=0, curbest=1000; j<item; j++) {
	 t = compare_cols(array[i].color, array[j].color);

	 /* finding minimum difference (maximal to all used colors) */
	 if (t < curbest) {
	    curbest = t;
	    if (t < mindiff)
	       break;
	 }
      }

      /* filling that minimum to 'key' field */
      array[i].key = curbest;
   }

   /* sort the array begind 'item' according to 'key' field */
   qsort(array + item, length - item, sizeof(ITEM), qsort_helper_ITEM);

   /* find the start of small values ('key') in array and safely reducing
    * the number of items we'll work with 
    */
   for (i = item; i < length; i++) {
      if (array[i].key < mindiff) {
	 length = i;
	 break;
      }
   }

   /* the most different color (from colors in [0,item)) */
   bestpos = item;
   best = array[item].key;

   /* swapping loop (the length goes from the size of palette) */
   for (i=item; i<palsize; i++) {
      /* the 'i'th best is already known */
      if (best < mindiff) {
	 return;
      }
      else {
	 int tmp;

	 /* swap the focused color and the one with 'bestpos' (the most
	  * different) index
	  */
	 tmp = array[bestpos].color;
	 array[bestpos] = array[i];
	 array[i].color = tmp;

	 /* fix the keys (can be only diminished with the last added color) */
	 for (j=i+1, best=-1; j<length; j++) {
	    t = compare_cols(array[i].color, array[j].color);
	    if (t < array[j].key) {
	       array[j].key = t;
	    }
	    /* find the maximum for swapping */
	    if (array[j].key > best) {
	       best = array[j].key;
	       bestpos = j;
	    }
	 }
      }
   }
}

// searches the array of length for the color
static bool no_such_color(ITEM* array, int length, int color, int mask) {
   for (int i = 0; i < length; i++) if ((array[i].color & mask) == color) return false;
   return true;
}

/* generate_optimized_palette_ex:
 *  Calculates a suitable palette for color reducing the specified truecolor
 *  image. If the reserved parameter is not NULL, it contains an array of
 *  256 flags. If reserved[n] > 0 the palette entry is assumed to be already 
 *  set so I count with it. If reserved[n] < 0 I mustn't assume anything about
 *  the entry. If reserved[n] == 0 the entry is free for me to change.
 * 
 *  Variable fraction controls, how big part of the palette should be
 *  filled with 'different colors', maxswaps gives upper boundary for
 *  number of swaps and mindiff chooses when to stop replacing values
 */
void generate_optimized_palette(RGBA[] image, RGBA[] palette, bool[] reserved = null, int bitsperrgb = DEFAULT_PREC, int fraction = DEFAULT_FRACTION, int maxswaps = DEFAULT_MAXSWAPS, int mindiff = DEFAULT_MINDIFF)
{
	int i, j, x, y, numcols, palsize, rsvdcnt=0, rsvduse=0;
	unsigned int prec_mask, prec_mask2, bitmask24;
	signed char tmprsvd[256];
	int rshift, gshift, bshift;
	ITEM[] colors;

	switch (bitsperrgb) {
		case 4:
			prec_mask = 0x3C3C3C;
			prec_mask2 = 0;
			bitmask24 = 0xF0F0F0;
		break;
		case 5:
			prec_mask = 0x3E3E3E;
			prec_mask2 = 0x3C3C3C;
			bitmask24 = 0xF8F8F8;
		break;
		default: throw(new Exception("Invalid bitsperrgb"));
	}

	distinct = 0;

	for (int n = 0; n < hash_table.length; n++) {
		hash_table[i].next = null;
		hash_table[i].color = -1;
		hash_table[i].count = 0;
	}

	/* count the number of colors we shouldn't modify */
	if (reserved) {
		for (i=0; i<256; i++) {
			if (!reserved[i]) continue;
			rsvdcnt++;
			if (reserved[i] > 0) rsvduse++;
		}
	} else {
		pal[0].r = 63;
		pal[0].g = 0;
		pal[0].b = 63;

		tmprsvd[0] = 1;
		rsvdcnt++;
		rsvduse++;

		for (i=1; i<256; i++) tmprsvd[i] = 0;

		reserved = tmprsvd;
	}

	// fix palette
	for (int n = 0; n < 0x100; n++) {
		palette[n].r &= 0x3F;
		palette[n].g &= 0x3F;
		palette[n].b &= 0x3F;
	}

	/* fill the 'hash_table' with 4bit per RGB color values */
	bmp_select(image);

	// imgdepth
	foreach (c; image) insert_node(c);

	// convert the 'hash_table' to array 'colors'
	colors.length = rsvduse + distinct;

   for (i = 0, j = rsvduse; i<hash_table.length; i++) {
      if (hash_table[i].count) {
	 NODE *node = &hash_table[i];

	 do {
	    colors[j].color = node->color;
	    colors[j++].key = node->count;
	    node = node->next;
	 } while (node != NULL);

	 if (hash_table[i].next)
	    delete_list(hash_table[i].next);
      }
   }

   /* sort the list with biggest count first */
   qsort(colors + rsvduse, distinct, sizeof(ITEM), qsort_helper_ITEM);

   /* we don't want to deal anymore with colors that are seldomly(?) used */
   numcols = rsvduse + distinct;
   palsize = 256 - rsvdcnt + rsvduse;

   /* change the format of the color information to some faster one
    * (in fact to the 00BBBB?0 00GGGG?0 00RRRR?0).
    */

	// imgdepth
	rshift = _rgb_r_shift_32 + 3;
	gshift = _rgb_g_shift_32 + 3;
	bshift = _rgb_b_shift_32 + 3;

   for (i = rsvduse; i < numcols; i++) {
      int r = (colors[i].color >> rshift) & 0x1F;
      int g = (colors[i].color >> gshift) & 0x1F;
      int b = (colors[i].color >> bshift) & 0x1F;
      colors[i].color = ((r << 1) | (g << 9) | (b << 17));
   }

   do {
      int start, k;

      /* there may be only small number of numcols colors, so we don't need
       * any optimization
       */
      if (numcols <= palsize) break;

      if (rsvduse > 0) {
	 /* copy 'rsvd' to the 'colors' */
	 for (i = 0, j = 0; i < rsvduse; j++)
	    if (reserved[j] > 0)
	       colors[i++].color = (pal[j].r | (pal[j].g << 8) | (pal[j].b << 16));

	 /* reduce 'colors' skipping colors contained in 'rsvd' palette */
	 for (i = rsvduse, j = i; i < numcols; i++)
	    if (no_such_color(colors, rsvduse, colors[i].color, prec_mask))
	       colors[j++].color = colors[i].color;

	 /* now there are j colors in 'common'  */
	 numcols = j;

	 /* now there might be enough free cells in palette */
	 if (numcols <= palsize)
	    break;
      }

      /* from 'start' will start swapping colors */
      start = palsize - palsize / fraction;

      /* it may be slow, so don't let replace too many colors */
      if (start < (palsize - maxswaps))
	 start = palsize - maxswaps;

      /* swap not less than 10 colors */
      if (start > (palsize - 10))
	 start = rsvduse;

      /* don't swap reserved colors */
      if (start < rsvduse)
	 start = rsvduse;

      if (bitsperrgb == 5) {
	 /* do second pass on the colors we'll possibly use to replace (lower
	    bits per pixel to 4) - this would effectively lower the maximum
	    number of different colors to some 4000 (from 32000) */
	 for (i = start, k = i; i < numcols; i++) {
	    for (j = 0; j < k; j++) {
	       if ((colors[j].color & prec_mask2) == (colors[i].color & prec_mask2)) {
		  j = -1;
		  break;
	       }
	    }
	    /* add this color if there is not similar one */
	    if (j != -1)
	       colors[k++].color = colors[i].color;
	 }

	 /* now there are k colors in 'common' */
	 numcols = k;

	 /* now there might be enough free cells in palette */
	 if (numcols <= palsize)
	    break;
      }

      /* start finding the most different colors */
      optimize_colors(colors, start, palsize, numcols, mindiff);

      numcols = palsize;
   } while (0);

   /* copy used colors to 'pal', skipping 'rsvd' */
   for (i = rsvduse, j = 0; i < numcols; j++)
      if (!reserved[j])
	 copy_color(&pal[j], colors[i++].color);

   _AL_FREE(colors);

   return distinct;
}
